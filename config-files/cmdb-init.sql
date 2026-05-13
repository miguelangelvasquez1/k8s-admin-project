CREATE TABLE IF NOT EXISTS categorias_activo (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL
);

CREATE TABLE IF NOT EXISTS activos_ti (
    id INT AUTO_INCREMENT PRIMARY KEY,
    codigo_activo VARCHAR(30) UNIQUE NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    categoria_id INT REFERENCES categorias_activo(id),
    fabricante VARCHAR(80),
    modelo VARCHAR(80),
    numero_serie VARCHAR(80),
    ip_asignada VARCHAR(15),
    responsable_uid VARCHAR(50),
    ubicacion VARCHAR(100),
    fecha_adquisicion DATE,
    fecha_ultimo_inventario DATE,
    estado VARCHAR(30) DEFAULT 'activo',
    observaciones TEXT
);

CREATE TABLE IF NOT EXISTS vulnerabilidades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    activo_id INT REFERENCES activos_ti(id),
    cve_id VARCHAR(20),
    severidad ENUM('critica','alta','media','baja') NOT NULL,
    descripcion TEXT,
    fecha_deteccion DATE,
    fecha_remediacion DATE,
    estado ENUM('detectada','en_proceso','remediada') DEFAULT 'detectada'
);

INSERT INTO categorias_activo (nombre) VALUES
    ('Servidor físico'), ('Switch'), ('Router'),
    ('Firewall'), ('Estación de trabajo'), ('Licencia software');

INSERT INTO activos_ti VALUES
    (1,'SRV-EPM-001','Servidor primario SAP ERP',1,'Dell','PowerEdge R750',
     'SN-DELL-2021-001','10.0.40.50','jperez','Data Center Piso 3',
     '2021-04-15','2023-08-10','activo','Inventario desactualizado 18 meses'),

    (2,'SRV-EPM-002','Servidor HCM Workday',1,'HP','ProLiant DL380 Gen10',
     'SN-HP-2020-042','10.0.40.51','mgarcia','Data Center Piso 3',
     '2020-11-20','2024-01-05','activo','OK'),

    (3,'SW-CORE-001','Switch Core principal',2,'Cisco','Catalyst 3650',
     'SN-CSC-2019-007','10.0.0.2','jperez','Rack A-01',
     '2019-06-01','2022-03-14','activo','Firmware desactualizado — sin parche'),

    (4,'FW-EPM-001','Firewall perimetral',4,'Cisco','ASA 5506-X',
     'SN-FW-2020-003','200.0.0.2','jperez','Rack A-02',
     '2020-01-10','2024-11-20','activo','OK'),

    (5,'WS-TI-042','Estación de trabajo retirado',5,'Lenovo','ThinkPad E15',
     'SN-LNV-2018-099',NULL,'lrojas','Bodega TI',
     '2018-09-01',NULL,'baja','Activo dado de baja sin inventario final');

-- Vulnerabilidades sin remediar (problema 4.3.3)
INSERT INTO vulnerabilidades (activo_id, cve_id, severidad, descripcion,
    fecha_deteccion, fecha_remediacion, estado) VALUES
    (1,'CVE-2024-1234','critica','RCE en módulo SAP sin parche aplicado',
     '2024-08-15',NULL,'detectada'),
    (3,'CVE-2023-5678','critica','Firmware Cisco vulnerable a MITM',
     '2023-11-20',NULL,'detectada'),
    (3,'CVE-2024-9101','alta','Buffer overflow en IOS XE',
     '2024-03-10',NULL,'en_proceso'),
    (1,'CVE-2024-1122','alta','Escalación de privilegios en OS del servidor',
     '2024-09-01',NULL,'detectada');