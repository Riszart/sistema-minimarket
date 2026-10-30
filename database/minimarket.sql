-- ============================================================================
-- SISTEMA DE VENTAS E INVENTARIO PARA BODEGA (MINIMARKET)
-- Script maestro de creación de base de datos
-- Motor : MySQL 8 / MariaDB 10.4+ (instalación local, sin internet - RNF-04)
-- Espejo de: document/diseño tecnico de base de datos.md (v2.1)
-- Alineado con: document/requerimientos.md (SRS v2.1)
--
-- AUDITORÍA (RF-32, RNF-08, RN-08):
--   * TODAS las tablas llevan created_at / updated_at (fecha y hora de
--     creación y de última modificación, automáticas).
--   * La bitácora `log_auditoria` guarda quién hizo qué, cuándo y con
--     qué valores antes/después. Es de solo escritura.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS `minimarket`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `minimarket`;

-- ---------------------------------------------------------------------------
-- TABLA: usuarios
-- Personal con acceso al sistema (RF-24, RNF-01, RNF-02)
-- No se siembra ningún usuario: el primer Admin se crea en la primera
-- ejecución del sistema (asistente de instalación - RF-24)
-- ---------------------------------------------------------------------------
CREATE TABLE `usuarios` (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `username`   VARCHAR(50) NOT NULL COMMENT 'Nombre para iniciar sesión',
  `password`   VARCHAR(255) NULL COMMENT 'Hash bcrypt — solo Administrador (RNF-01)',
  `pin`        VARCHAR(255) NULL COMMENT 'Hash del PIN — solo Cajero (RNF-02)',
  `rol`        ENUM('Administrador','Cajero') NOT NULL,
  `activo`     TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Baja lógica del empleado (RF-24)',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría (RNF-08)',
  `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría (RNF-08)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_usuarios_username` (`username`),
  KEY `ix_usuarios_rol` (`rol`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Personal con acceso al sistema';

-- ---------------------------------------------------------------------------
-- TABLA: categorias
-- Grupos de productos (evita inconsistencias al escribir categorías a mano)
-- ---------------------------------------------------------------------------
CREATE TABLE `categorias` (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `nombre`     VARCHAR(50) NOT NULL,
  `activo`     TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Baja lógica (RN-04)',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría (RNF-08)',
  `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría (RNF-08)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_categorias_nombre` (`nombre`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Grupos de productos (ej: Lácteos)';

-- ---------------------------------------------------------------------------
-- TABLA: productos
-- Inventario de la bodega (RF-11, RF-12, RF-13, RF-25)
-- ---------------------------------------------------------------------------
CREATE TABLE `productos` (
  `id`                 INT NOT NULL AUTO_INCREMENT,
  `codigo_barras`      VARCHAR(50) NULL COMMENT 'Vacío si no tiene código (RF-02)',
  `nombre`             VARCHAR(100) NOT NULL,
  `id_categoria`       INT NOT NULL,
  `tipo_unidad`        ENUM('Unidad','Kilogramo') NOT NULL DEFAULT 'Unidad' COMMENT 'RF-13',
  `precio_costo`       DECIMAL(10,2) NOT NULL COMMENT 'Último precio de compra',
  `precio_venta`       DECIMAL(10,2) NOT NULL COMMENT 'Precio al público, INCLUYE IGV (RN-02)',
  `stock`              DECIMAL(10,3) NOT NULL DEFAULT 0.000 COMMENT '3 decimales para Kilogramo',
  `stock_minimo`       DECIMAL(10,3) NOT NULL DEFAULT 3.000 COMMENT 'Alerta visual (RF-12)',
  `fecha_vencimiento`  DATE NULL COMMENT 'Reporte de vencimientos (RF-20)',
  `activo`             TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Baja lógica, conserva historial (RF-25)',
  `created_at`         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría: alta del producto (RNF-08)',
  `updated_at`         TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría: cambios de precio/stock (RF-25, RNF-08)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_productos_codigo` (`codigo_barras`),
  KEY `ix_productos_nombre` (`nombre`),
  KEY `ix_productos_stock` (`stock`),
  KEY `ix_productos_vencimiento` (`fecha_vencimiento`),
  CONSTRAINT `fk_productos_categoria` FOREIGN KEY (`id_categoria`) REFERENCES `categorias` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Inventario por unidad o kilogramo';

-- ---------------------------------------------------------------------------
-- TABLA: clientes
-- Control de la línea de crédito "fiados" (RF-04, RF-05, RF-06, RF-27)
-- ---------------------------------------------------------------------------
CREATE TABLE `clientes` (
  `id`              INT NOT NULL AUTO_INCREMENT,
  `documento`       VARCHAR(15) NULL COMMENT 'DNI o RUC',
  `nombre_completo` VARCHAR(100) NOT NULL,
  `telefono`        VARCHAR(15) NULL,
  `limite_credito`  DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Monto máximo a fiar (RF-05)',
  `saldo_deuda`     DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Deuda vigente; baja con abonos (RF-27)',
  `apto_credito`    TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Evaluación del cliente (RF-06, RN-01)',
  `activo`          TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Baja lógica (RN-04)',
  `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría: alta del cliente (RNF-08)',
  `updated_at`      TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría: cambios de deuda/límite (RNF-08)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_clientes_documento` (`documento`),
  KEY `ix_clientes_nombre` (`nombre_completo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Clientes con control de crédito';

-- ---------------------------------------------------------------------------
-- TABLA: ventas
-- Cabecera de cada boleta en caja (RF-09, RF-10, RF-21, RN-02, RN-07)
-- ---------------------------------------------------------------------------
CREATE TABLE `ventas` (
  `id`                 INT NOT NULL AUTO_INCREMENT,
  `numero_boleta`      VARCHAR(20) NOT NULL COMMENT 'Serie y correlativo: B001-000123 (RN-07)',
  `fecha`              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha y hora del hecho de la venta',
  `subtotal`           DECIMAL(10,2) NOT NULL COMMENT 'total / 1.18 (RF-03)',
  `igv`                DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'IGV 18% desglosado (RF-03)',
  `total`              DECIMAL(10,2) NOT NULL COMMENT 'subtotal + igv',
  `metodo_pago`        ENUM('Efectivo','Billetera Digital','Crédito') NOT NULL COMMENT 'RF-07',
  `estado`             ENUM('Activa','Anulada') NOT NULL DEFAULT 'Activa' COMMENT 'RF-21',
  `motivo_anulacion`   VARCHAR(150) NULL COMMENT 'Obligatorio al anular (RF-21)',
  `fecha_anulacion`    DATETIME NULL COMMENT 'Fecha y hora exacta de la anulación (RF-21)',
  `id_usuario`         INT NOT NULL COMMENT 'Cajero que realizó la venta (RF-09)',
  `id_cliente`         INT NULL COMMENT 'Nulo si es cliente casual',
  `id_usuario_anula`   INT NULL COMMENT 'Administrador que anuló (RF-21)',
  `created_at`         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría: cuándo se registró (RNF-08)',
  `updated_at`         TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría: cambia al anular (RNF-08)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ventas_boleta` (`numero_boleta`),
  KEY `ix_ventas_fecha` (`fecha`),
  KEY `ix_ventas_metodo` (`metodo_pago`),
  KEY `ix_ventas_usuario` (`id_usuario`),
  KEY `ix_ventas_cliente` (`id_cliente`),
  CONSTRAINT `fk_ventas_usuario`     FOREIGN KEY (`id_usuario`)       REFERENCES `usuarios` (`id`)     ON DELETE RESTRICT,
  CONSTRAINT `fk_ventas_cliente`     FOREIGN KEY (`id_cliente`)       REFERENCES `clientes` (`id`)     ON DELETE SET NULL,
  CONSTRAINT `fk_ventas_anulador`    FOREIGN KEY (`id_usuario_anula`) REFERENCES `usuarios` (`id`)     ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Cabecera de ventas (boletas)';

-- ---------------------------------------------------------------------------
-- TABLA: detalle_ventas
-- El "carrito" de cada venta (RF-08, RF-13, RF-17, RN-06)
-- ---------------------------------------------------------------------------
CREATE TABLE `detalle_ventas` (
  `id`                     INT NOT NULL AUTO_INCREMENT,
  `id_venta`               INT NOT NULL,
  `id_producto`            INT NOT NULL,
  `cantidad`               DECIMAL(10,3) NOT NULL COMMENT '0.500 si es medio kilo',
  `precio_unitario`        DECIMAL(10,2) NOT NULL COMMENT 'Precio CON IGV en ese instante (histórico)',
  `costo_unitario_momento` DECIMAL(10,2) NOT NULL COMMENT 'Costo histórico al vender: base de la ganancia (RF-17, RN-06)',
  `subtotal`               DECIMAL(10,2) NOT NULL COMMENT 'cantidad × precio_unitario',
  `created_at`             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría: alta del renglón (RNF-08)',
  `updated_at`             TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría (RNF-08)',
  PRIMARY KEY (`id`),
  KEY `ix_detalle_ventas_venta` (`id_venta`),
  KEY `ix_detalle_ventas_producto` (`id_producto`),
  CONSTRAINT `fk_dv_venta`    FOREIGN KEY (`id_venta`)    REFERENCES `ventas`    (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_dv_producto` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_dv_cantidad` CHECK (`cantidad` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Detalle de productos vendidos';

-- ---------------------------------------------------------------------------
-- TABLA: abonos_credito
-- Pagos parciales contra la deuda del cliente (RF-27, RF-28)
-- ---------------------------------------------------------------------------
CREATE TABLE `abonos_credito` (
  `id`           INT NOT NULL AUTO_INCREMENT,
  `id_cliente`   INT NOT NULL,
  `id_venta`     INT NULL COMMENT 'Boleta a crédito que cancela (opcional: deuda acumulada)',
  `fecha`        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha y hora del pago',
  `monto`        DECIMAL(10,2) NOT NULL COMMENT 'No puede exceder saldo_deuda (RF-27)',
  `metodo_pago`  ENUM('Efectivo','Billetera Digital') NOT NULL COMMENT 'RF-07',
  `id_usuario`   INT NOT NULL COMMENT 'Quién registró el abono',
  `observacion`  VARCHAR(150) NULL,
  `created_at`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría: fecha/hora de registro (RNF-08)',
  `updated_at`   TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría (RNF-08)',
  PRIMARY KEY (`id`),
  KEY `ix_abonos_cliente` (`id_cliente`),
  KEY `ix_abonos_venta` (`id_venta`),
  KEY `ix_abonos_usuario` (`id_usuario`),
  CONSTRAINT `fk_abonos_cliente`  FOREIGN KEY (`id_cliente`) REFERENCES `clientes` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_abonos_venta`    FOREIGN KEY (`id_venta`)   REFERENCES `ventas`   (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_abonos_usuario`  FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_abonos_monto`   CHECK (`monto` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Abonos/pagos a cuenta de clientes';

-- ---------------------------------------------------------------------------
-- TABLA: proveedores
-- Empresas que surten a la bodega (RF-14, RF-29)
-- Corrección v1.0: fecha_entrega y fecha_visita se movieron a `compras`
-- ---------------------------------------------------------------------------
CREATE TABLE `proveedores` (
  `id`             INT NOT NULL AUTO_INCREMENT,
  `nombre_empresa` VARCHAR(100) NOT NULL COMMENT 'RF-14',
  `contacto`       VARCHAR(100) NULL,
  `telefono`       VARCHAR(15) NULL,
  `activo`         TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Baja lógica, conserva historial (RF-29)',
  `created_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría: alta del proveedor (RNF-08)',
  `updated_at`     TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría (RNF-08)',
  PRIMARY KEY (`id`),
  KEY `ix_proveedores_nombre` (`nombre_empresa`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Distribuidores de mercadería';

-- ---------------------------------------------------------------------------
-- TABLA: compras
-- Factura / nota de entrega del proveedor (RF-15, RF-16)
-- ---------------------------------------------------------------------------
CREATE TABLE `compras` (
  `id`                 INT NOT NULL AUTO_INCREMENT,
  `numero_comprobante` VARCHAR(50) NULL COMMENT 'N° de factura o boleta del proveedor (RF-15)',
  `fecha`              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha y hora del hecho: ingreso de mercadería',
  `fecha_entrega`      DATE NULL COMMENT 'Fecha de entrega pactada (RF-15)',
  `metodo_pago`        ENUM('Efectivo','Billetera Digital','Crédito') NOT NULL COMMENT 'RF-15',
  `total`              DECIMAL(10,2) NOT NULL COMMENT 'Monto total invertido',
  `id_proveedor`       INT NOT NULL COMMENT 'RF-14',
  `id_usuario`         INT NULL COMMENT 'Administrador que registró la compra',
  `created_at`         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría: fecha/hora de registro (RNF-08)',
  `updated_at`         TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría (RNF-08)',
  PRIMARY KEY (`id`),
  KEY `ix_compras_fecha` (`fecha`),
  KEY `ix_compras_proveedor` (`id_proveedor`),
  KEY `ix_compras_usuario` (`id_usuario`),
  CONSTRAINT `fk_compras_proveedor` FOREIGN KEY (`id_proveedor`) REFERENCES `proveedores` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_compras_usuario`   FOREIGN KEY (`id_usuario`)   REFERENCES `usuarios`    (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Compras de mercadería a proveedores';

-- ---------------------------------------------------------------------------
-- TABLA: detalle_compras
-- Desglose de productos de cada compra (RF-16)
-- ---------------------------------------------------------------------------
CREATE TABLE `detalle_compras` (
  `id`             INT NOT NULL AUTO_INCREMENT,
  `id_compra`      INT NOT NULL,
  `id_producto`    INT NOT NULL,
  `cantidad`       DECIMAL(10,3) NOT NULL COMMENT 'Suma al stock (RF-16)',
  `costo_unitario` DECIMAL(10,2) NOT NULL COMMENT 'Costo de compra en ese instante',
  `subtotal`       DECIMAL(10,2) NOT NULL COMMENT 'cantidad × costo_unitario',
  `created_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría: fecha/hora de registro (RNF-08)',
  `updated_at`     TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría (RNF-08)',
  PRIMARY KEY (`id`),
  KEY `ix_dc_compra` (`id_compra`),
  KEY `ix_dc_producto` (`id_producto`),
  CONSTRAINT `fk_dc_compra`    FOREIGN KEY (`id_compra`)   REFERENCES `compras`   (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_dc_producto`  FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_dc_cantidad` CHECK (`cantidad` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Detalle de mercadería comprada';

-- ---------------------------------------------------------------------------
-- TABLA: ajustes_inventario
-- Trazabilidad de mermas, daños, vencimientos y conteos (RF-26)
-- ---------------------------------------------------------------------------
CREATE TABLE `ajustes_inventario` (
  `id`               INT NOT NULL AUTO_INCREMENT,
  `fecha`            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha y hora del hecho del ajuste',
  `id_producto`      INT NOT NULL,
  `tipo`             ENUM('Merma','Daño','Vencimiento','Conteo físico','Otro') NOT NULL COMMENT 'RF-26',
  `cantidad`         DECIMAL(10,3) NOT NULL COMMENT 'Negativa RESTA stock, positiva SUMA (RF-26)',
  `stock_resultante` DECIMAL(10,3) NOT NULL COMMENT 'Stock luego del ajuste',
  `motivo`           VARCHAR(150) NOT NULL COMMENT 'Descripción obligatoria (RF-26)',
  `id_usuario`       INT NOT NULL COMMENT 'Quién ejecutó el ajuste',
  `created_at`       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría: fecha/hora de registro (RNF-08)',
  `updated_at`       TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría (RNF-08)',
  PRIMARY KEY (`id`),
  KEY `ix_ajustes_producto` (`id_producto`),
  KEY `ix_ajustes_fecha` (`fecha`),
  CONSTRAINT `fk_ajustes_producto` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_ajustes_usuario`  FOREIGN KEY (`id_usuario`)  REFERENCES `usuarios`  (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_ajustes_cantidad` CHECK (`cantidad` <> 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Movimientos de stock que no son ventas ni compras';

-- ---------------------------------------------------------------------------
-- TABLA: correlativos
-- Control automático de la numeración de comprobantes que emite el sistema (RN-07)
-- ---------------------------------------------------------------------------
CREATE TABLE `correlativos` (
  `id`                INT NOT NULL AUTO_INCREMENT,
  `tipo_comprobante`  ENUM('Boleta','Factura') NOT NULL,
  `serie`             VARCHAR(10) NOT NULL COMMENT 'Ej: B001',
  `ultimo_numero`     INT NOT NULL DEFAULT 0 COMMENT 'Último correlativo emitido',
  `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Auditoría: creación de la serie (RNF-08)',
  `updated_at`        TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Auditoría: cambia con cada boleta emitida (RNF-08)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_correlativos_tipo` (`tipo_comprobante`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Control de serie y correlativo de boletas (RN-07)';

-- ---------------------------------------------------------------------------
-- TABLA: log_auditoria  (NUEVA EN v2.1)
-- Bitácora central de auditoría: quién, cuándo, qué cambió y valores
-- antes/después. SOLO ESCRITURA: nunca se actualiza ni se borra (RN-08).
-- Se llena desde el backend dentro de la MISMA transacción que el cambio.
-- ---------------------------------------------------------------------------
CREATE TABLE `log_auditoria` (
  `id`              BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Alto volumen: por eso BIGINT',
  `fecha_hora`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha y hora EXACTA del cambio (RF-32)',
  `id_usuario`      INT NULL COMMENT 'Autor del cambio; NULL si es el sistema',
  `tabla`           VARCHAR(30) NOT NULL COMMENT 'Tabla afectada (ej: productos)',
  `id_registro`     INT NULL COMMENT 'PK del registro afectado',
  `accion`          ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  `campo`           VARCHAR(50) NULL COMMENT 'Campo puntual si el cambio fue de un solo campo',
  `valor_anterior`  JSON NULL COMMENT 'Valores previos del registro',
  `valor_nuevo`     JSON NULL COMMENT 'Valores posteriores del registro',
  `descripcion`     VARCHAR(255) NULL COMMENT 'Resumen legible del cambio',
  PRIMARY KEY (`id`),
  KEY `ix_log_fecha` (`fecha_hora`),
  KEY `ix_log_tabla` (`tabla`),
  KEY `ix_log_usuario` (`id_usuario`),
  KEY `ix_log_registro` (`tabla`, `id_registro`),
  CONSTRAINT `fk_log_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Bitácora de auditoría de todos los cambios (RF-32, RN-08, RNF-08)';

-- ============================================================================
-- DATOS SEMILLA
-- ============================================================================

INSERT INTO `categorias` (`nombre`) VALUES
  ('Abarrotes'),
  ('Bebidas'),
  ('Lácteos'),
  ('Limpieza'),
  ('Snacks');

INSERT INTO `correlativos` (`tipo_comprobante`, `serie`, `ultimo_numero`) VALUES
  ('Boleta', 'B001', 0);

-- NOTA: No se siembra ningún usuario con contraseña por seguridad.
-- El sistema debe crear el primer Administrador en su primera ejecución
-- (asistente de instalación - RF-24 / RNF-01); ese alta queda registrada
-- automáticamente en `log_auditoria`.
-- La tabla `log_auditoria` se siembra vacía: solo se llena con el uso
-- real del sistema.
-- ============================================================================
