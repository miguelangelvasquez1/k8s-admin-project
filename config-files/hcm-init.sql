CREATE TABLE IF NOT EXISTS departamentos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    codigo VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS empleados (
    id SERIAL PRIMARY KEY,
    uid_ldap VARCHAR(50),
    numero_empleado VARCHAR(20) UNIQUE NOT NULL,
    nombre_completo VARCHAR(150) NOT NULL,
    email VARCHAR(150),
    departamento_id INTEGER REFERENCES departamentos(id),
    cargo VARCHAR(100),
    fecha_ingreso DATE,
    fecha_retiro DATE,
    estado VARCHAR(30) DEFAULT 'activo',
    sincronizado_ldap BOOLEAN DEFAULT FALSE,
    ultima_sincronizacion TIMESTAMP
);

CREATE TABLE IF NOT EXISTS log_sincronizacion (
    id SERIAL PRIMARY KEY,
    uid_ldap VARCHAR(50),
    accion VARCHAR(50),
    descripcion TEXT,
    fecha TIMESTAMP DEFAULT NOW(),
    resultado VARCHAR(20)
);

INSERT INTO departamentos (nombre, codigo) VALUES
    ('Tecnología de la Información', 'TI-001'),
    ('Operaciones', 'OPS-002'),
    ('Recursos Humanos', 'RRHH-003'),
    ('Gestión de Activos', 'GAC-004');

INSERT INTO empleados (uid_ldap, numero_empleado, nombre_completo, email,
    departamento_id, cargo, fecha_ingreso, fecha_retiro, estado,
    sincronizado_ldap, ultima_sincronizacion) VALUES

-- Empleado activo SINCRONIZADO correctamente
('jperez', '1001', 'Juan Pérez', 'juan.perez@epm.com.co',
    1, 'Ingeniero TI', '2019-03-15', NULL, 'activo', TRUE, NOW()),

-- Empleado activo SINCRONIZADO correctamente
('mgarcia', '1002', 'María García', 'maria.garcia@epm.com.co',
    2, 'Analista Operaciones', '2020-07-01', NULL, 'activo', TRUE, NOW()),

-- Ex-empleado: HCM dice RETIRADO, pero LDAP aún lo tiene activo
('lrojas', '0842', 'Luis Rojas', 'luis.rojas@epm.com.co',
    1, 'Soporte TI', '2017-01-10', '2024-06-30', 'retirado',
    FALSE, '2024-06-30'),   -- <-- nunca se sincronizó la baja al AD

-- Ex-empleada: HCM dice RETIRADA, LDAP aún activa
('alopez', '0735', 'Andrea López', 'andrea.lopez@epm.com.co',
    3, 'Coordinadora RRHH', '2016-05-20', '2024-09-15', 'retirado',
    FALSE, '2024-09-15'),   -- <-- brecha de integridad

-- Empleado NUEVO en HCM que AÚN NO existe en LDAP (falta sincronización)
(NULL, '1103', 'Carlos Mendoza', 'carlos.mendoza@epm.com.co',
    1, 'Arquitecto Cloud', '2025-02-01', NULL, 'activo',
    FALSE, NULL);           -- <-- ingresó pero no tiene cuenta AD todavía

INSERT INTO log_sincronizacion (uid_ldap, accion, descripcion, resultado) VALUES
    ('lrojas', 'BAJA', 'Retiro procesado en HCM. Pendiente desactivar en AD.', 'PENDIENTE'),
    ('alopez', 'BAJA', 'Retiro procesado en HCM. Pendiente desactivar en AD.', 'PENDIENTE'),
    (NULL,     'ALTA', 'Nuevo empleado Carlos Mendoza. Pendiente crear cuenta AD.', 'PENDIENTE');