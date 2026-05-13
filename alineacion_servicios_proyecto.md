# Alineación de Servicios Desplegados con el Proyecto EPM

**Proyecto:** Administración de Infraestructura de TI — Grupo EPM  
**Universidad del Quindío · Ingeniería de Sistemas y Computación · 2026-1**

---

## 1. Contexto general

El proyecto identifica debilidades críticas en la infraestructura de TI de EPM documentadas en el *Informe de Control del Sistema de Control Interno — Segundo Semestre 2025* (EPM Inversiones, 2025a). El prototipo desplegado en Minikube simula, a escala de laboratorio, la arquitectura de servicios que EPM requiere fortalecer. Cada contenedor en el clúster responde directamente a una necesidad, problema u oportunidad identificada en el documento.

---

## 2. Mapa de alineación

| Servicio desplegado | Imagen | Sección del documento | Problema / Necesidad que representa |
|---|---|---|---|
| `epm-ldap` (OpenLDAP) | `tiredofit/openldap` | §4.3.1 | Directorio Activo con cuentas de ex-empleados activas |
| `epm-ldap-ui` (phpLDAPadmin) | `osixia/phpldapadmin` | §4.3.1 | Interfaz de gestión del directorio — control de accesos |
| `epm-hcm` (PostgreSQL) | `postgres:15` | §4.3.2 | Sistema HCM desincronizado con el Directorio Activo |
| `epm-cmdb` (MySQL) | `mysql:8.0` | §4.3.2 | CMDB con registros desactualizados e inconsistentes |
| `epm-erp` (Nginx) | `nginx:alpine` | §4.3.2 / §4.4.1 | ERP en transición — inconsistencias HCM ↔ AD visibles |
| `epm-adminer` | `adminer:4.8.1` | §4.2.2 | Herramienta de gestión de activos de TI (HCM + CMDB) |
| `epm-wazuh-indexer` | `wazuh/wazuh-indexer` | §4.2.3 / §4.3.3 | Almacenamiento de eventos de seguridad del SOC |
| `epm-wazuh-manager` | `wazuh/wazuh-manager` | §4.3.3 | Motor de detección — reglas personalizadas EPM |
| `epm-wazuh-dashboard` | `wazuh/wazuh-dashboard` | §4.2.3 | Dashboard del Centro de Operaciones de Seguridad (SOC) |

---

## 3. Alineación detallada por problema del documento

### 3.1 Problema §4.3.1 — Brechas en el control de accesos

> *"El informe de control interno identifica debilidades en el Directorio Activo de EPM, incluyendo la existencia de cuentas activas de ex-empleados, perfiles que no corresponden al rol asignado y ausencia de políticas de inactivación."*

**Servicios que lo demuestran:** `epm-ldap` + `epm-ldap-ui`

El archivo `epm.ldif` cargado al contenedor OpenLDAP contiene deliberadamente dos usuarios en estado `employeeType: RETIRADO-NO-DESACTIVADO`:

- `uid=lrojas` — retirado el 30/06/2024, cuenta aún activa en el directorio
- `uid=alopez` — retirada el 15/09/2024, cuenta aún activa en el directorio

Estos usuarios son visibles en phpLDAPadmin bajo `ou=empleados,dc=epm,dc=com,dc=co`, lo que simula exactamente la situación que el informe de control interno describe: cuentas que debieron inactivarse pero permanecen operativas.

---

### 3.2 Problema §4.3.2 — Calidad e integridad de los datos

> *"Se documentan problemas de sincronización y falta de integridad entre sistemas de información, particularmente entre el sistema de gestión de capital humano HCM y el Directorio Activo. La CMDB presenta registros desactualizados e inconsistentes."*

**Servicios que lo demuestran:** `epm-hcm` + `epm-cmdb` + `epm-erp` + `epm-adminer`

**HCM (PostgreSQL):** La tabla `empleados` contiene el campo `sincronizado_ldap`. Los registros de `lrojas` y `alopez` tienen `sincronizado_ldap = FALSE` y un log en `log_sincronizacion` con `resultado = 'PENDIENTE'`. El empleado `cmendoza` tiene `uid_ldap = NULL` — existe en HCM pero no tiene cuenta en el directorio, la brecha inversa.

**CMDB (MySQL):** La tabla `activos_ti` incluye:
- `SRV-EPM-001`: `fecha_ultimo_inventario = 2023-08-10` — inventario desactualizado 18 meses
- `WS-TI-042`: activo dado de baja sin inventario final, `fecha_ultimo_inventario = NULL`
- `SW-CORE-001`: firmware desactualizado sin parche

La tabla `vulnerabilidades` registra 4 CVEs sin remediar, todos con `estado IN ('detectada', 'en_proceso')` y `fecha_remediacion = NULL`.

**ERP (Nginx):** La página HTML muestra una tabla de sincronización HCM ↔ AD con las brechas marcadas visualmente en rojo, conectando ambos problemas en una sola vista.

---

### 3.3 Problema §4.3.3 — Vulnerabilidades de infraestructura sin remediar

> *"Se reporta una alta proporción de vulnerabilidades críticas identificadas pero no remediadas, junto con una madurez insuficiente en capacidades de Threat Hunting, Cyber Threat Intelligence y Attack Surface Management."*

**Servicios que lo demuestran:** `epm-wazuh-manager` + `epm-wazuh-indexer` + `epm-wazuh-dashboard`

El archivo `custom-rules.xml` cargado al Wazuh Manager define cuatro reglas personalizadas EPM:

| ID Regla | Nivel | Evento que detecta | Relación con el documento |
|---|---|---|---|
| 100001 | 12 | Login fallido repetido (fuerza bruta) | Madurez SOC — detección activa |
| 100002 | 15 | Login de `lrojas` o `alopez` | Cuentas ex-empleados — §4.3.1 |
| 100003 | 10 | Acceso fuera de horario laboral | Política de accesos — §4.3.1 |
| 100004 | 8 | Cambio en CMDB sin autorización | Integridad de configuración — §4.3.2 |

El dashboard de Wazuh representa el SOC cuya madurez insuficiente está documentada en el informe. Las reglas de nivel 12–15 son alertas críticas equivalentes a las que el SOC real de EPM debería estar procesando.

---

### 3.4 Necesidad §4.2.2 — Gestión integral de activos de TI

> *"El Grupo EPM requiere un control estricto, completo y actualizado del inventario de hardware y software."*

**Servicio que lo demuestra:** `epm-adminer`

Adminer permite conectarse tanto a la base HCM (PostgreSQL) como a la CMDB (MySQL) y visualizar directamente el estado de los activos, sus vulnerabilidades y el log de sincronización. Representa la capa de consulta y gestión sobre los sistemas de información que el documento identifica como críticos.

---

### 3.5 Necesidad §4.2.1 — Centralización y servicios compartidos

> *"Esta arquitectura centralizada genera la necesidad permanente de contar con una infraestructura de cómputo robusta, virtualizada y con alta disponibilidad."*

**Representado por:** el clúster Minikube en su conjunto

La orquestación con Kubernetes simula exactamente el modelo que EPM necesita: todos los servicios corren en un solo clúster con namespaces, servicios con DNS interno (`hcm-db`, `cmdb-db`, `openldap`, `wazuh-manager`), volúmenes persistentes y políticas de reinicio. Esto es la versión de laboratorio de una infraestructura centralizada con alta disponibilidad.

---

### 3.6 Oportunidad §4.4.1 — Transformación digital de procesos

> *"La automatización de flujos de trabajo administrativos y operativos mediante TI permite crear una organización más ágil."*

**Representado por:** la integración LDAP ↔ HCM ↔ ERP

El prototipo muestra el estado actual (brechas de sincronización) y, por contraste, señala hacia dónde debería ir la solución: automatización del ciclo de vida del empleado desde HCM hasta el directorio, con el ERP como superficie de visualización integrada.

---

## 4. Diagrama de relaciones entre servicios y problemas

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLÚSTER MINIKUBE (epm)                       │
│                                                                  │
│  §4.3.1 Control de accesos          §4.2.3 / §4.3.3 SOC         │
│  ┌─────────────────────┐            ┌──────────────────────┐    │
│  │  OpenLDAP           │            │  Wazuh Indexer       │    │
│  │  (Directorio AD)    │◄──alerta───│  Wazuh Manager       │    │
│  │  lrojas / alopez    │  regla     │  Wazuh Dashboard     │    │
│  │  cuentas activas    │  100002    │  Reglas EPM custom   │    │
│  └──────────┬──────────┘            └──────────────────────┘    │
│             │ brecha de                                          │
│             │ sincronización         §4.2.2 Gestión activos      │
│  §4.3.2 Integridad datos            ┌──────────────────────┐    │
│  ┌──────────▼──────────┐            │  Adminer             │    │
│  │  HCM (PostgreSQL)   │◄───────────│  (consulta HCM       │    │
│  │  cmendoza sin AD    │            │   y CMDB)            │    │
│  │  lrojas/alopez      │            └──────────────────────┘    │
│  │  sin sync           │                                        │
│  └──────────┬──────────┘                                        │
│             │                                                    │
│  ┌──────────▼──────────┐   §4.3.2 CMDB desactualizada           │
│  │  ERP Web (Nginx)    │   ┌──────────────────────┐             │
│  │  Tabla brechas      │   │  CMDB (MySQL)         │             │
│  │  HCM ↔ AD          │   │  CVEs sin remediar    │             │
│  │  visibles           │   │  inventario vencido   │             │
│  └─────────────────────┘   └──────────────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Conclusión

El prototipo no es una solución a los problemas de EPM — es una **demostración controlada** de esos problemas. Cada dato en cada base de datos fue diseñado para reflejar un hallazgo específico del informe de control interno. La orquestación con Kubernetes agrega la dimensión de §4.2.1: muestra que una infraestructura centralizada, virtualizada y gestionada como clúster es el modelo hacia el cual EPM debe evolucionar para garantizar disponibilidad, escalabilidad y control sobre sus 19 filiales nacionales.