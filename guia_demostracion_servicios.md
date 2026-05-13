# Guía de demostración — Servicios EPM en Minikube

**Cómo abrir cada servicio, qué mostrar y cómo se relacionan entre sí**

---

## Antes de empezar — obtener las URLs

Ejecutá este comando para ver todas las URLs activas:

```bash
minikube service list -n epm
```

La salida será similar a esta — anotá las URLs:

```
|-----------|--------------------------|-------------|---------------------------|
| NAMESPACE |          NAME            | TARGET PORT |            URL            |
|-----------|--------------------------|-------------|---------------------------|
| epm       | epm-adminer-svc          | 8888        | http://192.168.49.2:XXXXX |
| epm       | epm-erp-svc              | 8090        | http://192.168.49.2:XXXXX |
| epm       | epm-ldap-ui-svc          | 8081        | http://192.168.49.2:XXXXX |
| epm       | epm-wazuh-dashboard-svc  | 443         | http://192.168.49.2:XXXXX |
|-----------|--------------------------|-------------|---------------------------|
```

También podés abrir cada uno directamente con:

```bash
minikube service epm-ldap-ui-svc -n epm
minikube service epm-adminer-svc -n epm
minikube service epm-erp-svc -n epm
minikube service epm-wazuh-dashboard-svc -n epm
```

---

## Servicio 1 — phpLDAPadmin (Directorio Activo simulado)

**URL:** `http://192.168.49.2:XXXXX` (puerto del `epm-ldap-ui-svc`)  
**Problema que demuestra:** §4.3.1 — Cuentas activas de ex-empleados

### Cómo entrar

1. Abrís la URL en el navegador
2. Clic en **"login"** (panel izquierdo)
3. Credenciales:
   - **Login DN:** `cn=admin,dc=epm,dc=com,dc=co`
   - **Password:** `Epm@Admin2025`
4. Clic en **"Authenticate"**

### Qué mostrar

Una vez dentro, en el árbol izquierdo navegás a:

```
dc=epm,dc=com,dc=co
  └── ou=empleados
        ├── uid=jperez        ← empleado activo, sincronizado ✓
        ├── uid=mgarcia       ← empleado activo, sincronizado ✓
        ├── uid=lrojas        ← RETIRADO — cuenta aún activa ✗
        └── uid=alopez        ← RETIRADA — cuenta aún activa ✗
```

**Clic en `uid=lrojas`** → mostrar el atributo `employeeType: RETIRADO-NO-DESACTIVADO`  
**Clic en `uid=alopez`** → igual

**Qué decir en la sustentación:**
> "Este es el Directorio Activo simulado de EPM. Los usuarios `lrojas` y `alopez` tienen fecha de retiro en HCM pero sus cuentas permanecen activas en el directorio. Cualquier persona con sus credenciales podría seguir autenticándose en sistemas críticos. Esto es exactamente la brecha §4.3.1 del informe de control interno."

---

## Servicio 2 — ERP Web (Nginx)

**URL:** `http://192.168.49.2:XXXXX` (puerto del `epm-erp-svc`)  
**Problema que demuestra:** §4.3.2 — Falta de integridad HCM ↔ Directorio Activo

### Cómo entrar

Abrís la URL directamente — no requiere login.

### Qué mostrar

La página carga automáticamente con:

- **Banner EPM** en azul corporativo
- **Alerta roja** de sistema con los usuarios problemáticos identificados
- **Tabla de sincronización** con tres estados:
  - `jperez` / `mgarcia` → Sincronizado (verde)
  - `lrojas` / `alopez` → **BRECHA — cuenta no desactivada** (rojo)
  - `cmendoza` → **BRECHA — sin cuenta AD** (naranja)

**Qué decir en la sustentación:**
> "Este módulo ERP muestra el estado de sincronización entre el sistema HCM y el Directorio Activo. La alerta de sistema refleja el hallazgo §4.3.2: `lrojas` y `alopez` siguen activos en AD aunque HCM los marca como retirados. `cmendoza` es el caso inverso — existe en HCM pero no tiene cuenta AD todavía. Esta es la falta de integridad entre sistemas que el documento describe."

---

## Servicio 3 — Adminer (Gestión de bases de datos)

**URL:** `http://192.168.49.2:XXXXX` (puerto del `epm-adminer-svc`)  
**Problema que demuestra:** §4.2.2 y §4.3.2 — Gestión de activos y calidad de datos

Adminer se conecta a **dos bases de datos distintas**. Mostrás cada una por separado.

---

### 3a — Conectarse a HCM (PostgreSQL)

En la pantalla de login de Adminer:

| Campo | Valor |
|---|---|
| System | PostgreSQL |
| Server | `hcm-db` |
| Username | `hcm_admin` |
| Password | `Epm@HCM2025` |
| Database | `hcm_epm` |

#### Qué mostrar en HCM

**Tabla `empleados`** → Clic en "Select" al lado de `empleados`

Columnas clave para mostrar:
- `lrojas`: `estado = retirado`, `sincronizado_ldap = false`, `fecha_retiro = 2024-06-30`
- `alopez`: `estado = retirado`, `sincronizado_ldap = false`, `fecha_retiro = 2024-09-15`
- `cmendoza`: `estado = activo`, `uid_ldap = NULL`, `sincronizado_ldap = false`

**Tabla `log_sincronizacion`** → muestra los tres registros `PENDIENTE`

**Qué decir:**
> "En la tabla de empleados del HCM vemos que `lrojas` y `alopez` figuran como retirados, pero el campo `sincronizado_ldap` es `false` — la baja nunca se propagó al directorio. Y `cmendoza` lleva activo desde febrero de 2025 sin cuenta AD. El log de sincronización confirma las tres acciones pendientes."

---

### 3b — Conectarse a CMDB (MySQL)

Clic en **"Logout"** en Adminer, luego nuevo login:

| Campo | Valor |
|---|---|
| System | MySQL |
| Server | `cmdb-db` |
| Username | `cmdb_admin` |
| Password | `Epm@CMDB2025` |
| Database | `cmdb_epm` |

#### Qué mostrar en CMDB

**Tabla `activos_ti`** → Clic en "Select"

Registros clave:
- `SRV-EPM-001`: `fecha_ultimo_inventario = 2023-08-10` — **más de 18 meses sin actualizar**
- `WS-TI-042`: `fecha_ultimo_inventario = NULL`, `estado = baja` — **activo dado de baja sin inventario final**
- `SW-CORE-001`: `observaciones = "Firmware desactualizado — sin parche"`

**Tabla `vulnerabilidades`** → Clic en "Select"

Mostrar los 4 registros con `fecha_remediacion = NULL`:
- 2 de severidad `critica`
- 2 de severidad `alta`
- Todos con `estado IN ('detectada', 'en_proceso')`

**Qué decir:**
> "Esta es la CMDB del Grupo EPM simulada. El servidor SAP primario tiene el inventario desactualizado hace 18 meses — exactamente el hallazgo §4.3.2. Y acá en vulnerabilidades vemos los CVEs críticos sin remediar: el `CVE-2024-1234` sobre el módulo SAP lleva desde agosto de 2024 detectado y sin parche aplicado. Esto es la alta proporción de vulnerabilidades críticas sin remediar del §4.3.3."

---

## Servicio 4 — Wazuh Dashboard (SOC)

**URL:** `http://192.168.49.2:XXXXX` (puerto del `epm-wazuh-dashboard-svc`)  
**Problema que demuestra:** §4.2.3 y §4.3.3 — Madurez del SOC y vulnerabilidades

### Cómo entrar

1. Abrís la URL — puede mostrar advertencia de certificado, aceptás de todas formas (Advanced → Proceed)
2. Credenciales:
   - **Username:** `admin`
   - **Password:** `Epm@Index2025!`

> Si el dashboard no carga de inmediato, esperá 1-2 minutos — Wazuh tarda en inicializar completamente.

### Qué mostrar

#### Vista principal — Overview

La pantalla de inicio muestra el dashboard del SOC con:
- Eventos detectados
- Agentes registrados
- Alertas por nivel de severidad

#### Reglas personalizadas EPM

Navegás a **Management → Rules** y buscás el grupo `epm-custom`:

| Regla | Nivel | Descripción |
|---|---|---|
| 100001 | 12 | Fuerza bruta — login fallido repetido |
| 100002 | 15 | Login de ex-empleado `lrojas` o `alopez` — CRÍTICO |
| 100003 | 10 | Acceso fuera de horario laboral |
| 100004 | 8 | Cambio en CMDB sin autorización |

**Qué decir:**
> "Este es el Centro de Operaciones de Seguridad simulado. Las reglas del grupo `epm-custom` fueron diseñadas para los problemas específicos de EPM: la regla 100002 es nivel 15 — el más crítico — y se dispara cuando cualquier sistema detecta un login de `lrojas` o `alopez`, los ex-empleados que vimos en el directorio. El SOC real de EPM tiene exactamente esta brecha de madurez que describe el §4.3.3: capacidades de detección insuficientes y vulnerabilidades críticas sin proceso activo de remediación."

---

## Servicio 5 — Dashboard de Kubernetes (Minikube)

**No necesita URL manual** — se abre con:

```bash
minikube dashboard
```

### Qué mostrar

Este dashboard es ideal para mostrar la arquitectura completa del clúster:

- **Workloads → Deployments**: todos los 9 deployments en estado `Available`
- **Workloads → Pods**: todos los pods en `Running`
- **Config → Config Maps**: los 5 ConfigMaps creados (hcm-init-sql, cmdb-init-sql, etc.)
- **Storage → Persistent Volume Claims**: los 5 PVCs en estado `Bound`
- **Discovery → Services**: todos los servicios con sus puertos

**Qué decir:**
> "Este es el clúster Kubernetes que orquesta todo el prototipo. Los 9 servicios corriendo en el namespace `epm` simulan la arquitectura centralizada que EPM necesita para sus 19 filiales nacionales — §4.2.1. Los ConfigMaps contienen los datos de negocio, los PVCs garantizan persistencia, y los servicios internos se comunican por DNS sin exponer puertos al exterior."

---

## Cómo se relacionan todos los servicios entre sí

```
                    ┌──────────────────┐
                    │   MINIKUBE       │
                    │   namespace: epm │
                    └────────┬─────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
  ┌─────────────┐    ┌──────────────┐    ┌──────────────────┐
  │  IDENTIDAD  │    │    DATOS     │    │    SEGURIDAD     │
  │             │    │              │    │                  │
  │ OpenLDAP    │◄───│ ERP (Nginx)  │    │ Wazuh Indexer    │
  │ phpLDAPadmin│    │ muestra las  │    │ Wazuh Manager ───┼──► regla 100002
  │             │    │ brechas de   │    │ Wazuh Dashboard  │    detecta login
  └──────┬──────┘    │ sync         │    │                  │    de lrojas/alopez
         │           └──────┬───────┘    └──────────────────┘
         │ brecha de        │
         │ sync             │ lee de
         ▼                   ▼
  ┌─────────────────────────────────┐
  │         BASES DE DATOS          │
  │                                 │
  │  HCM (PostgreSQL — hcm-db)      │◄── Adminer (visualización)
  │  empleados: lrojas retirado     │
  │  sin sincronizar LDAP           │
  │                                 │
  │  CMDB (MySQL — cmdb-db)         │◄── Adminer (visualización)
  │  activos desactualizados        │
  │  CVEs sin remediar              │
  └─────────────────────────────────┘
```

### Flujo de demostración recomendado para la sustentación

```
1. minikube dashboard      → mostrar arquitectura general (todos los pods Running)
         │
         ▼
2. phpLDAPadmin            → mostrar lrojas/alopez con cuentas activas (§4.3.1)
         │
         ▼
3. ERP Web                 → mostrar tabla de brechas HCM ↔ AD (§4.3.2)
         │
         ▼
4. Adminer → HCM           → mostrar empleados retirados sin sync, cmendoza sin AD
         │
         ▼
5. Adminer → CMDB          → mostrar activos desactualizados + CVEs sin remediar (§4.3.3)
         │
         ▼
6. Wazuh Dashboard         → mostrar SOC y reglas EPM custom (§4.2.3)
```

Este orden cuenta una historia coherente: primero el problema de identidad, luego cómo ese problema se refleja en los sistemas de datos, y finalmente cómo el SOC debería (pero actualmente no logra del todo) detectarlo.

---

## Comandos de verificación rápida antes de la sustentación

```bash
# Todo corriendo
kubectl get pods -n epm

# URLs de acceso
minikube service list -n epm

# Si algún pod falla, ver el error
kubectl describe pod <nombre-pod> -n epm
kubectl logs <nombre-pod> -n epm

# Reiniciar un pod problemático
kubectl rollout restart deployment/<nombre-deployment> -n epm
```

---

## Credenciales de acceso — resumen

| Servicio | URL | Usuario | Contraseña |
|---|---|---|---|
| phpLDAPadmin | `minikube service epm-ldap-ui-svc -n epm` | `cn=admin,dc=epm,dc=com,dc=co` | `Epm@Admin2025` |
| Adminer (HCM) | `minikube service epm-adminer-svc -n epm` | `hcm_admin` / server: `hcm-db` | `Epm@HCM2025` |
| Adminer (CMDB) | `minikube service epm-adminer-svc -n epm` | `cmdb_admin` / server: `cmdb-db` | `Epm@CMDB2025` |
| ERP Web | `minikube service epm-erp-svc -n epm` | *(sin login)* | — |
| Wazuh Dashboard | `minikube service epm-wazuh-dashboard-svc -n epm` | `admin` | `Epm@Index2025!` |
| Kubernetes Dashboard | `minikube dashboard` | *(automático)* | — |