-- =========================================================
--  DB Y LIMPIEZA
-- =========================================================
-- CREATE DATABASE IF NOT EXISTS db_genesisapp;
USE db_genesisapp;

SET FOREIGN_KEY_CHECKS=0;
DROP TABLE IF EXISTS movimiento_general;
DROP TABLE IF EXISTS tarjeta_credito;
DROP TABLE IF EXISTS cuenta_monetaria;
DROP TABLE IF EXISTS cuenta_ahorro;
DROP TABLE IF EXISTS usuario;
DROP TABLE IF EXISTS catalogo;
SET FOREIGN_KEY_CHECKS=1;

-- =========================================================
--  CATALOGO
-- =========================================================
CREATE TABLE catalogo (
    cat_id_catalogo INT AUTO_INCREMENT PRIMARY KEY,
    cat_tipo_catalogo VARCHAR(50) NOT NULL,    -- p.ej.: estado_usuario, moneda, estado_producto, tipo_movimiento, estado_movimiento, tipo_producto, naturaleza_mov, canal_mov
    cat_valor        VARCHAR(50) NOT NULL,     -- código: A/I, GTQ/USD, ACT/BLOQ/BAJA, DEP/RET/..., CR/DB, APP/WEB/ATM/OFI
    cat_descripcion  VARCHAR(255),
    cat_estado       CHAR(1) DEFAULT 'A',
    cat_fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cat_fecha_mod      TIMESTAMP NULL DEFAULT NULL,
    UNIQUE KEY uq_catalogo_tipo_valor (cat_tipo_catalogo, cat_valor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================================================
--  USUARIO
-- =========================================================
-- Tabla CATALOGO (ya la tienes así, con índice único compuesto)
-- UNIQUE KEY uq_catalogo_tipo_valor (cat_tipo_catalogo, cat_valor)

CREATE TABLE usuario (
  usr_id_usuario INT AUTO_INCREMENT PRIMARY KEY,
  usr_nombres VARCHAR(100) NOT NULL,
  usr_apellidos VARCHAR(100) NOT NULL,
  usr_alias VARCHAR(50),
  usr_email VARCHAR(100) NOT NULL UNIQUE,
  usr_contrasena_hash VARCHAR(255) NOT NULL,
  usr_estado_tipo   VARCHAR(50) NOT NULL DEFAULT 'estado_usuario',
  usr_estado_valor  CHAR(1)     NOT NULL,
  usr_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  usr_fecha_modificacion TIMESTAMP NULL DEFAULT NULL,

  CONSTRAINT fk_usuario_estado
    FOREIGN KEY (usr_estado_tipo, usr_estado_valor)
    REFERENCES catalogo (cat_tipo_catalogo, cat_valor)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================================================
--  PRODUCTOS INDIVIDUALES (sin tabla base)
-- =========================================================

-- AHORRO
CREATE TABLE cuenta_ahorro (
    aho_id INT AUTO_INCREMENT PRIMARY KEY,
    aho_id_usuario INT NOT NULL,
    aho_numero_cuenta VARCHAR(20) NOT NULL UNIQUE,
    aho_id_moneda INT NOT NULL,     -- FK catalogo(moneda)
    aho_id_estado INT NOT NULL,     -- FK catalogo(estado_producto)
    aho_saldo_disponible DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    aho_saldo_flotante DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    aho_tasa_interes DECIMAL(5,2) NULL,
    aho_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    aho_fecha_mod TIMESTAMP NULL DEFAULT NULL,
    CONSTRAINT fk_aho_user FOREIGN KEY (aho_id_usuario) REFERENCES usuario(usr_id_usuario)
      ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_aho_moneda FOREIGN KEY (aho_id_moneda) REFERENCES catalogo(cat_id_catalogo)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_aho_estado FOREIGN KEY (aho_id_estado) REFERENCES catalogo(cat_id_catalogo)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_aho_user (aho_id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- MONETARIA (corriente)
CREATE TABLE cuenta_monetaria (
    mon_id INT AUTO_INCREMENT PRIMARY KEY,
    mon_id_usuario INT NOT NULL,
    mon_numero_cuenta VARCHAR(20) NOT NULL UNIQUE,
    mon_id_moneda INT NOT NULL,
    mon_id_estado INT NOT NULL,
    mon_saldo_disponible DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    mon_saldo_flotante DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    mon_sobregiro_permitido DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    mon_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    mon_fecha_mod TIMESTAMP NULL DEFAULT NULL,
    CONSTRAINT fk_mon_user FOREIGN KEY (mon_id_usuario) REFERENCES usuario(usr_id_usuario)
      ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mon_moneda FOREIGN KEY (mon_id_moneda) REFERENCES catalogo(cat_id_catalogo)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_mon_estado FOREIGN KEY (mon_id_estado) REFERENCES catalogo(cat_id_catalogo)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_mon_user (mon_id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TARJETA DE CRÉDITO
CREATE TABLE tarjeta_credito (
    tarj_id INT AUTO_INCREMENT PRIMARY KEY,
    tarj_id_usuario INT NOT NULL,
    tarj_numero_tarjeta VARCHAR(25) NOT NULL UNIQUE,
    tarj_id_moneda INT NOT NULL,
    tarj_id_estado INT NOT NULL,
    tarj_limite_credito DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    tarj_saldo_actual DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    tarj_saldo_flotante DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    tarj_tasa_interes DECIMAL(5,2) NULL,
    tarj_fecha_corte DATE NULL,
    tarj_fecha_pago DATE NULL,
    tarj_pago_minimo DECIMAL(15,2) NULL,
    tarj_fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tarj_fecha_mod TIMESTAMP NULL DEFAULT NULL,
    CONSTRAINT fk_tarj_user FOREIGN KEY (tarj_id_usuario) REFERENCES usuario(usr_id_usuario)
      ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tarj_moneda FOREIGN KEY (tarj_id_moneda) REFERENCES catalogo(cat_id_catalogo)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tarj_estado FOREIGN KEY (tarj_id_estado) REFERENCES catalogo(cat_id_catalogo)
      ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_tarj_user (tarj_id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================================================
--  MOVIMIENTO GENERAL (único para todos los productos)
-- =========================================================
CREATE TABLE movimiento_general (
    mov_id INT AUTO_INCREMENT PRIMARY KEY,
    -- Identificación del producto afectado
    mov_producto_id   INT NOT NULL,      -- ID en su tabla (aho_id / mon_id / tarj_id / externo)
    mov_id_causa      INT NOT NULL,      -- FK catalogo causa_contable
    mov_id_naturaleza INT NOT NULL,      -- FK catalogo('naturaleza_mov': CR/DB)
    mov_id_canal      INT NOT NULL,      -- FK catalogo('canal_mov': APP/WEB/ATM/OFI)
    mov_id_estado     INT NOT NULL,      -- FK catalogo('estado_movimiento': PEND/APL/REV)
    -- Importes y saldos
    mov_id_moneda     INT NOT NULL,      -- FK catalogo('moneda')
    mov_monto         DECIMAL(15,2) NOT NULL,
    mov_tipo_cambio   DECIMAL(18,6) NULL,     -- si hay conversión
    mov_saldo_antes   DECIMAL(15,2) NULL,
    mov_saldo_despues DECIMAL(15,2) NULL,
    -- Contraparte (para transferencias/pagos/terceros)
    mov_contraparte_tipo INT NULL,            -- AHO/MON/TAR/EXT (catalogo:'tipo_producto')
    mov_contraparte_id   INT NULL,            -- id interno si aplica
    mov_contraparte_numero VARCHAR(30) NULL,  -- número de cuenta/tarjeta o referencia externa
    mov_contraparte_banco  VARCHAR(80) NULL,  -- banco externo trasnferencias ACH

    -- Auditoría y referencias
    mov_referencia_externa VARCHAR(50) NULL,  -- id de autorización trazabilidad para cada operacion
    mov_detalle            VARCHAR(255) NULL,
    mov_fecha_creacion     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    mov_usuario_registra   VARCHAR(100) NULL,
    -- FKs a catálogos
    CONSTRAINT fk_mov_causa         FOREIGN KEY (mov_id_causa)          REFERENCES catalogo(cat_id_catalogo),
    CONSTRAINT fk_mov_nat           FOREIGN KEY (mov_id_naturaleza)     REFERENCES catalogo(cat_id_catalogo),
    CONSTRAINT fk_mov_canal         FOREIGN KEY (mov_id_canal)          REFERENCES catalogo(cat_id_catalogo),
    CONSTRAINT fk_mov_estado        FOREIGN KEY (mov_id_estado)         REFERENCES catalogo(cat_id_catalogo),
    CONSTRAINT fk_mov_moneda        FOREIGN KEY (mov_id_moneda)         REFERENCES catalogo(cat_id_catalogo),
    CONSTRAINT fk_mov_contra_tipo   FOREIGN KEY (mov_contraparte_tipo)  REFERENCES catalogo(cat_id_catalogo),
    -- Creacion de indices por tamaño transaccional
    INDEX idx_mov_prod ( mov_producto_id),
    INDEX idx_mov_causa (mov_id_causa),
    INDEX idx_mov_estado (mov_id_estado),
    INDEX idx_mov_crea (mov_fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

