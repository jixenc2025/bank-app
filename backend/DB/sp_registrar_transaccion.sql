DROP PROCEDURE IF EXISTS sp_registrar_transaccion;
DELIMITER $$

/**
 * sp_registrar_transaccion
 * ------------------------------------------------------------
 * Registra movimientos financieros y actualiza saldos de productos.
 *
 * OPERACIONES
 *  - 'MOV' : Movimiento simple (un solo producto). 
 *            Ej: DEP/RET en ahorro/monetaria, COMPRA/PAGO en TC.
 *  - 'TRX' : Transferencia a terceros (de origen a destino) en una sola llamada.
 *            Registra DB en origen y CR en destino, y actualiza saldos de ambos.
 *
 * PARÁMETROS (por valor de catálogo, ej. tipo_producto: '1','2','3'; moneda: '0','1')
 *  p_operacion             'MOV' | 'TRX'
 *
 *  -- ORIGEN (siempre)
 *  p_origen_tipo_valor     '1'=Ahorro, '2'=Monetaria, '3'=Tarjeta
 *  p_origen_id             INT (aho_id/mon_id/tarj_id)
 *  p_origen_moneda_valor   '0'=GTQ, '1'=USD
 *  p_monto                 DECIMAL(15,2) > 0
 *  p_causa_origen_valor    VARCHAR (por tu codificación ej. 01020)
 *  p_naturaleza_origen     'CR'|'DB'
 *
 *  -- DESTINO (requerido si p_operacion='TRX'; ignorado en 'MOV')
 *  p_destino_tipo_valor    '1'|'2'|'3'
 *  p_destino_id            INT
 *  p_destino_moneda_valor  '0'|'1'
 *  p_causa_destino_valor   VARCHAR (ej. 01010)
 *  p_naturaleza_destino    'CR'|'DB'  (normalmente 'CR')
 *
 *  -- Metadatos comunes
 *  p_canal_valor           'APP'|'WEB'|'AGE'
 *  p_estado_mov_valor      'APR'|'PEND'|'REV'  (sugerido 'APR')
 *  p_referencia            VARCHAR(50)  (usa el mismo valor para ligar asientos)
 *  p_detalle               VARCHAR(255)
 *  p_usuario_registra      VARCHAR(100)
 *
 * RESPUESTA
 *  Primer result set:
 *    status_code: 0=OK, 1=VALIDATION, 2=NOT_FOUND, 3=RULE, 9=ERROR
 *    message
 *    mov_id: id del movimiento insertado (en 'MOV'); en 'TRX' devuelve el id del asiento de DESTINO
 *
 * NOTAS
 *  - No realiza conversión de moneda (FX). Debe coincidir producto vs. movimiento.
 *  - Estados de producto no operables: BLOQ, EMBR, CANC.
 *  - Monetaria permite sobregiro hasta mon_sobregiro_permitido.
 *  - Tarjeta: DB = compra (aumenta saldo_actual, valida límite). CR = pago (reduce saldo_actual).
 *  - En 'TRX' se registran dos filas en movimiento_general con la MISMA p_referencia.
 * SP creado por: Jhonathan Ixen
 
 */
CREATE PROCEDURE sp_registrar_transaccion(
    IN  p_operacion             VARCHAR(3),

    IN  p_origen_tipo_valor     VARCHAR(10),
    IN  p_origen_id             INT,
    IN  p_origen_moneda_valor   VARCHAR(5),
    IN  p_monto                 DECIMAL(15,2),
    IN  p_causa_origen_valor    VARCHAR(10),
    IN  p_naturaleza_origen     CHAR(2),

    IN  p_destino_tipo_valor    VARCHAR(10),
    IN  p_destino_id            INT,
    IN  p_destino_moneda_valor  VARCHAR(5),
    IN  p_causa_destino_valor   VARCHAR(10),
    IN  p_naturaleza_destino    CHAR(2),

    IN  p_canal_valor           VARCHAR(5),
    IN  p_estado_mov_valor      VARCHAR(5),
    IN  p_referencia            VARCHAR(50),
    IN  p_detalle               VARCHAR(255),
    IN  p_usuario_registra      VARCHAR(100)
)
main: BEGIN
    /* ---------- Declaración de variables ---------- */
    -- Catálogos comunes
    DECLARE v_id_moneda_origen   INT;
    DECLARE v_id_moneda_dest     INT;
    DECLARE v_id_causa_origen    INT;
    DECLARE v_id_causa_destino   INT;
    DECLARE v_id_nat_origen      INT;
    DECLARE v_id_nat_destino     INT;
    DECLARE v_id_canal           INT;
    DECLARE v_id_estado          INT;
    DECLARE v_id_tp_origen       INT;
    DECLARE v_id_tp_destino      INT;

    -- Datos producto origen
    DECLARE v_est_prod_ori INT;
    DECLARE v_mon_prod_ori INT;
    DECLARE v_saldo_disp_o DECIMAL(15,2);
    DECLARE v_saldo_flot_o DECIMAL(15,2);
    DECLARE v_sobregiro_o  DECIMAL(15,2);
    DECLARE v_limite_tc_o  DECIMAL(15,2);
    DECLARE v_saldo_tc_o   DECIMAL(15,2);
    DECLARE v_saldo_antes_o DECIMAL(15,2);
    DECLARE v_saldo_desp_o  DECIMAL(15,2);

    -- Datos producto destino (solo TRX)
    DECLARE v_est_prod_des INT;
    DECLARE v_mon_prod_des INT;
    DECLARE v_saldo_disp_d DECIMAL(15,2);
    DECLARE v_saldo_flot_d DECIMAL(15,2);
    DECLARE v_sobregiro_d  DECIMAL(15,2);
    DECLARE v_limite_tc_d  DECIMAL(15,2);
    DECLARE v_saldo_tc_d   DECIMAL(15,2);
    DECLARE v_saldo_antes_d DECIMAL(15,2);
    DECLARE v_saldo_desp_d  DECIMAL(15,2);
    
    -- IDs de movimientos
    DECLARE v_mov_id_origen  INT;
    DECLARE v_mov_id_destino INT;
    
    /* ---------- Validaciones de parámetros para evitar errores en operaciones finales ---------- */
    IF p_operacion IS NULL OR (p_operacion NOT IN ('MOV','TRX')) THEN
        SELECT 1 AS status_code, 'p_operacion inválida.' AS message, NULL AS mov_id; LEAVE main;
    END IF;

    IF p_origen_tipo_valor IS NULL OR p_origen_id IS NULL OR p_monto IS NULL 
       OR p_origen_moneda_valor IS NULL OR p_causa_origen_valor IS NULL 
       OR p_naturaleza_origen IS NULL OR p_canal_valor IS NULL THEN
        SELECT 1 AS status_code, 'Faltan parámetros obligatorios de ORIGEN.' AS message, NULL AS mov_id; LEAVE main;
    END IF;

    IF p_monto <= 0 THEN
        SELECT 1 AS status_code, 'El monto debe ser mayor a 0.' AS message, NULL AS mov_id; LEAVE main;
    END IF;

    IF p_operacion='TRX' THEN
        IF p_destino_tipo_valor IS NULL OR p_destino_id IS NULL 
           OR p_destino_moneda_valor IS NULL OR p_causa_destino_valor IS NULL 
           OR p_naturaleza_destino IS NULL THEN
            SELECT 1 AS status_code, 'Faltan parámetros de DESTINO para TRX.' AS message, NULL AS mov_id; LEAVE main;
        END IF;
    END IF;

    /* ---------- Resolver IDs de catálogos ---------- */
    SET v_id_tp_origen = (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='tipo_producto' AND cat_valor=p_origen_tipo_valor LIMIT 1);
    SET v_id_moneda_origen = (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='moneda' AND cat_valor=p_origen_moneda_valor LIMIT 1);
    SET v_id_causa_origen = (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='tipo_causa_mov' AND cat_valor=p_causa_origen_valor LIMIT 1);
    SET v_id_nat_origen   = (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='naturaleza_mov' AND cat_valor=p_naturaleza_origen LIMIT 1);
    SET v_id_canal        = (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='canal_mov' AND cat_valor=p_canal_valor LIMIT 1);
    SET v_id_estado       = (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='estado_movimiento' AND cat_valor=IFNULL(p_estado_mov_valor,'APR') LIMIT 1);

    IF v_id_tp_origen IS NULL OR v_id_moneda_origen IS NULL OR v_id_causa_origen IS NULL 
       OR v_id_nat_origen IS NULL OR v_id_canal IS NULL OR v_id_estado IS NULL THEN
        SELECT 1 AS status_code, 'Catálogo inválido en ORIGEN (tipo/moneda/causa/naturaleza/canal/estado).' AS message, NULL AS mov_id; LEAVE main;
    END IF;

    IF p_operacion='TRX' THEN
        SET v_id_tp_destino = (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='tipo_producto' AND cat_valor=p_destino_tipo_valor LIMIT 1);
        SET v_id_moneda_dest = (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='moneda' AND cat_valor=p_destino_moneda_valor LIMIT 1);
        SET v_id_causa_destino = (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='tipo_causa_mov' AND cat_valor=p_causa_destino_valor LIMIT 1);
        SET v_id_nat_destino   = (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='naturaleza_mov' AND cat_valor=p_naturaleza_destino LIMIT 1);

        IF v_id_tp_destino IS NULL OR v_id_moneda_dest IS NULL OR v_id_causa_destino IS NULL OR v_id_nat_destino IS NULL THEN
            SELECT 1 AS status_code, 'Catálogo inválido en DESTINO (tipo/moneda/causa/naturaleza).' AS message, NULL AS mov_id; LEAVE main;
        END IF;
    END IF;

    START TRANSACTION;

    /* =========================================================
       ORIGEN: carga y validaciones + actualización de saldo
       ========================================================= */
    IF p_origen_tipo_valor='1' THEN
        -- Ahorro (ORIGEN)
        SELECT aho_id_estado, aho_id_moneda, aho_saldo_disponible, aho_saldo_flotante
          INTO v_est_prod_ori, v_mon_prod_ori, v_saldo_disp_o, v_saldo_flot_o
        FROM cuenta_ahorro WHERE aho_id = p_origen_id FOR UPDATE;

        IF v_est_prod_ori IS NULL THEN ROLLBACK; SELECT 2 AS status_code, 'Cuenta no encontrada como producto Ahorro' AS message, NULL AS mov_id; LEAVE main; END IF;
        IF v_est_prod_ori IN (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='estado_producto' AND cat_valor IN ('BLOQ','EMBR','CANC'))
           THEN ROLLBACK; SELECT 3 AS status_code, 'Cuenta con estado distinta a Activa' AS message, NULL AS mov_id; LEAVE main; END IF;
        IF v_mon_prod_ori <> v_id_moneda_origen
           THEN ROLLBACK; SELECT 1 AS status_code, 'Moneda ORIGEN no coincide' AS message, NULL AS mov_id; LEAVE main; END IF;

        SET v_saldo_antes_o = v_saldo_disp_o;
        IF p_naturaleza_origen='CR' THEN
            SET v_saldo_desp_o = v_saldo_antes_o + p_monto;
            UPDATE cuenta_ahorro SET aho_saldo_disponible = v_saldo_desp_o WHERE aho_id = p_origen_id;
        ELSEIF p_naturaleza_origen='DB' THEN
            IF v_saldo_antes_o < p_monto
               THEN ROLLBACK; SELECT 3 AS status_code, 'Fondos insuficientes.' AS message, NULL AS mov_id; LEAVE main; END IF;
            SET v_saldo_desp_o = v_saldo_antes_o - p_monto;
            UPDATE cuenta_ahorro SET aho_saldo_disponible = v_saldo_desp_o WHERE aho_id = p_origen_id;
        ELSE
            ROLLBACK; SELECT 1 AS status_code, 'Solo se permiten Creditos o Debitos' AS message, NULL AS mov_id; LEAVE main;
        END IF;

    ELSEIF p_origen_tipo_valor='2' THEN
        -- Monetaria (ORIGEN)
        SELECT mon_id_estado, mon_id_moneda, mon_saldo_disponible, mon_saldo_flotante, mon_sobregiro_permitido
          INTO v_est_prod_ori, v_mon_prod_ori, v_saldo_disp_o, v_saldo_flot_o, v_sobregiro_o
        FROM cuenta_monetaria WHERE mon_id = p_origen_id FOR UPDATE;

        IF v_est_prod_ori IS NULL THEN ROLLBACK; SELECT 2 AS status_code, 'Cuenta no encontrada como producto Monetaria' AS message, NULL AS mov_id; LEAVE main; END IF;
        IF v_est_prod_ori IN (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='estado_producto' AND cat_valor IN ('BLOQ','EMBR','CANC'))
           THEN ROLLBACK; SELECT 3 AS status_code, 'Cuenta con estado distinta a Activa' AS message, NULL AS mov_id; LEAVE main; END IF;
        IF v_mon_prod_ori <> v_id_moneda_origen
           THEN ROLLBACK; SELECT 1 AS status_code, 'Moneda ORIGEN no coincide' AS message, NULL AS mov_id; LEAVE main; END IF;

        SET v_saldo_antes_o = v_saldo_disp_o;
        IF p_naturaleza_origen='CR' THEN
            SET v_saldo_desp_o = v_saldo_antes_o + p_monto;
            UPDATE cuenta_monetaria SET mon_saldo_disponible = v_saldo_desp_o WHERE mon_id = p_origen_id;
        ELSEIF p_naturaleza_origen='DB' THEN
            IF (v_saldo_antes_o + v_sobregiro_o) < p_monto
               THEN ROLLBACK; SELECT 3 AS status_code, 'Fondos insuficientes.' AS message, NULL AS mov_id; LEAVE main; END IF;
            SET v_saldo_desp_o = v_saldo_antes_o - p_monto;
            UPDATE cuenta_monetaria SET mon_saldo_disponible = v_saldo_desp_o WHERE mon_id = p_origen_id;
        ELSE
            ROLLBACK; SELECT 1 AS status_code, 'Solo se permiten Creditos o Debitos' AS message, NULL AS mov_id; LEAVE main;
        END IF;

    ELSEIF p_origen_tipo_valor='3' THEN
        -- Tarjeta (ORIGEN)
        SELECT tarj_id_estado, tarj_id_moneda, tarj_saldo_actual, tarj_saldo_flotante, tarj_limite_credito
          INTO v_est_prod_ori, v_mon_prod_ori, v_saldo_tc_o, v_saldo_flot_o, v_limite_tc_o
        FROM tarjeta_credito WHERE tarj_id = p_origen_id FOR UPDATE;

        IF v_est_prod_ori IS NULL THEN ROLLBACK; SELECT 2 AS status_code, 'Tarjeta no encontrada.' AS message, NULL AS mov_id; LEAVE main; END IF;
        IF v_est_prod_ori IN (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='estado_producto' AND cat_valor IN ('BLOQ','EMBR','CANC'))
           THEN ROLLBACK; SELECT 3 AS status_code, 'Tarjeta con estado distinto a Activa' AS message, NULL AS mov_id; LEAVE main; END IF;
        IF v_mon_prod_ori <> v_id_moneda_origen
           THEN ROLLBACK; SELECT 1 AS status_code, 'Moneda no coincide con tarjeta.' AS message, NULL AS mov_id; LEAVE main; END IF;

        SET v_saldo_antes_o = v_saldo_tc_o;
        IF p_naturaleza_origen='DB' THEN
            -- Consumo (sube saldo_actual), validar límite
            IF (v_saldo_antes_o + p_monto) > v_limite_tc_o
               THEN ROLLBACK; SELECT 3 AS status_code, 'Sobrepasa límite de tarjeta ORIGEN.' AS message, NULL AS mov_id; LEAVE main; END IF;
            SET v_saldo_desp_o = v_saldo_antes_o + p_monto;
            UPDATE tarjeta_credito SET tarj_saldo_actual = v_saldo_desp_o WHERE tarj_id = p_origen_id;
        ELSEIF p_naturaleza_origen='CR' THEN
            -- Pago/abono (baja saldo_actual). No dejamos negativo.
            SET v_saldo_desp_o = GREATEST(0, v_saldo_antes_o - p_monto);
            UPDATE tarjeta_credito SET tarj_saldo_actual = v_saldo_desp_o WHERE tarj_id = p_origen_id;
        ELSE
            ROLLBACK; SELECT 1 AS status_code, 'Solo se permiten Creditos o Debitos' AS message, NULL AS mov_id; LEAVE main;
        END IF;

    ELSE
        ROLLBACK; SELECT 1 AS status_code, 'No existe el producto enviado.' AS message, NULL AS mov_id; LEAVE main;
    END IF;

    /* Insert movimiento ORIGEN */
    INSERT INTO movimiento_general
    (mov_producto_id, mov_id_causa, mov_id_naturaleza, mov_id_canal, mov_id_estado,
     mov_id_moneda, mov_monto, mov_saldo_antes, mov_saldo_despues,
     mov_contraparte_tipo, mov_contraparte_id, mov_contraparte_numero, mov_contraparte_banco,
     mov_referencia_externa, mov_detalle, mov_usuario_registra)
    VALUES
    (p_origen_id, v_id_causa_origen, v_id_nat_origen, v_id_canal, v_id_estado,
     v_id_moneda_origen, p_monto, v_saldo_antes_o, v_saldo_desp_o,
     v_id_tp_destino, p_destino_id, NULL, NULL,
     p_referencia, CONCAT('[ORIGEN] ', p_detalle), p_usuario_registra);

    SET v_mov_id_origen = LAST_INSERT_ID();

    /* =========================================================
       DESTINO: solo si TRX. Valida existencia y actualiza saldo
       ========================================================= */
    IF p_operacion='TRX' THEN
        -- Validar moneda ORIGEN vs DESTINO (sin FX)
        IF v_id_moneda_origen <> v_id_moneda_dest THEN
            ROLLBACK; SELECT 1 AS status_code, 'Moneda distinta entre ORIGEN y DESTINO (no se permite Cambio de moneda FX).' AS message, NULL AS mov_id; LEAVE main;
        END IF;

        IF p_destino_tipo_valor='1' THEN
            -- Ahorro (DESTINO)
            SELECT aho_id_estado, aho_id_moneda, aho_saldo_disponible, aho_saldo_flotante
              INTO v_est_prod_des, v_mon_prod_des, v_saldo_disp_d, v_saldo_flot_d
            FROM cuenta_ahorro WHERE aho_id = p_destino_id FOR UPDATE;

            IF v_est_prod_des IS NULL THEN ROLLBACK; SELECT 2 AS status_code, 'Producto no encontrado.' AS message, NULL AS mov_id; LEAVE main; END IF;
            IF v_est_prod_des IN (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='estado_producto' AND cat_valor IN ('BLOQ','EMBR','CANC'))
               THEN ROLLBACK; SELECT 3 AS status_code, 'Producto con estado distinto a Activo' AS message, NULL AS mov_id; LEAVE main; END IF;
            IF v_mon_prod_des <> v_id_moneda_dest
               THEN ROLLBACK; SELECT 1 AS status_code, 'Moneda no coincide.' AS message, NULL AS mov_id; LEAVE main; END IF;

            SET v_saldo_antes_d = v_saldo_disp_d;
            IF p_naturaleza_destino='CR' THEN
                SET v_saldo_desp_d = v_saldo_antes_d + p_monto;
                UPDATE cuenta_ahorro SET aho_saldo_disponible = v_saldo_desp_d WHERE aho_id = p_destino_id;
            ELSEIF p_naturaleza_destino='DB' THEN
                IF v_saldo_antes_d < p_monto
                   THEN ROLLBACK; SELECT 3 AS status_code, 'Fondos insuficientes' AS message, NULL AS mov_id; LEAVE main; END IF;
                SET v_saldo_desp_d = v_saldo_antes_d - p_monto;
                UPDATE cuenta_ahorro SET aho_saldo_disponible = v_saldo_desp_d WHERE aho_id = p_destino_id;
            ELSE
                ROLLBACK; SELECT 1 AS status_code, 'Solo se permiten Creditos o Debitos'  AS message, NULL AS mov_id; LEAVE main;
            END IF;

        ELSEIF p_destino_tipo_valor='2' THEN
            -- Monetaria (DESTINO)
            SELECT mon_id_estado, mon_id_moneda, mon_saldo_disponible, mon_saldo_flotante, mon_sobregiro_permitido
              INTO v_est_prod_des, v_mon_prod_des, v_saldo_disp_d, v_saldo_flot_d, v_sobregiro_d
            FROM cuenta_monetaria WHERE mon_id = p_destino_id FOR UPDATE;

            IF v_est_prod_des IS NULL THEN ROLLBACK; SELECT 2 AS status_code, 'Producto no encontrado.' AS message, NULL AS mov_id; LEAVE main; END IF;
            IF v_est_prod_des IN (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='estado_producto' AND cat_valor IN ('BLOQ','EMBR','CANC'))
               THEN ROLLBACK; SELECT 3 AS status_code, 'Producto con estado distinto a Activo' AS message, NULL AS mov_id; LEAVE main; END IF;
            IF v_mon_prod_des <> v_id_moneda_dest
               THEN ROLLBACK; SELECT 1 AS status_code, 'Moneda no coincide.' AS message, NULL AS mov_id; LEAVE main; END IF;

            SET v_saldo_antes_d = v_saldo_disp_d;
            IF p_naturaleza_destino='CR' THEN
                SET v_saldo_desp_d = v_saldo_antes_d + p_monto;
                UPDATE cuenta_monetaria SET mon_saldo_disponible = v_saldo_desp_d WHERE mon_id = p_destino_id;
            ELSEIF p_naturaleza_destino='DB' THEN
                IF (v_saldo_antes_d + v_sobregiro_d) < p_monto
                   THEN ROLLBACK; SELECT 3 AS status_code, 'Fondos insuficientes.' AS message, NULL AS mov_id; LEAVE main; END IF;
                SET v_saldo_desp_d = v_saldo_antes_d - p_monto;
                UPDATE cuenta_monetaria SET mon_saldo_disponible = v_saldo_desp_d WHERE mon_id = p_destino_id;
            ELSE
                ROLLBACK; SELECT 1 AS status_code, 'Solo se permiten Creditos o Debitos'  AS message, NULL AS mov_id; LEAVE main;
            END IF;

        ELSEIF p_destino_tipo_valor='3' THEN
            -- Tarjeta (DESTINO)
            SELECT tarj_id_estado, tarj_id_moneda, tarj_saldo_actual, tarj_saldo_flotante, tarj_limite_credito
              INTO v_est_prod_des, v_mon_prod_des, v_saldo_tc_d, v_saldo_flot_d, v_limite_tc_d
            FROM tarjeta_credito WHERE tarj_id = p_destino_id FOR UPDATE;

            IF v_est_prod_des IS NULL THEN ROLLBACK; SELECT 2 AS status_code, 'Tarjeta no encontrada.' AS message, NULL AS mov_id; LEAVE main; END IF;
            IF v_est_prod_des IN (SELECT cat_id_catalogo FROM catalogo WHERE cat_tipo_catalogo='estado_producto' AND cat_valor IN ('BLOQ','EMBR','CANC'))
               THEN ROLLBACK; SELECT 3 AS status_code, 'Tarjeta con estado distinto a Activo' AS message, NULL AS mov_id; LEAVE main; END IF;
            IF v_mon_prod_des <> v_id_moneda_dest
               THEN ROLLBACK; SELECT 1 AS status_code, 'Moneda no coincide con tarjeta.' AS message, NULL AS mov_id; LEAVE main; END IF;

            SET v_saldo_antes_d = v_saldo_tc_d;
            IF p_naturaleza_destino='DB' THEN
                -- Débito en tarjeta (raro), validamos límite
                IF (v_saldo_antes_d + p_monto) > v_limite_tc_d
                   THEN ROLLBACK; SELECT 3 AS status_code, 'Sobrepasa límite de tarjeta DESTINO.' AS message, NULL AS mov_id; LEAVE main; END IF;
                SET v_saldo_desp_d = v_saldo_antes_d + p_monto;
                UPDATE tarjeta_credito SET tarj_saldo_actual = v_saldo_desp_d WHERE tarj_id = p_destino_id;
            ELSEIF p_naturaleza_destino='CR' THEN
                -- Pago a tarjeta (lo usual en TRX a tarjeta)
                SET v_saldo_desp_d = GREATEST(0, v_saldo_antes_d - p_monto);
                UPDATE tarjeta_credito SET tarj_saldo_actual = v_saldo_desp_d WHERE tarj_id = p_destino_id;
            ELSE
                ROLLBACK; SELECT 1 AS status_code, 'Solo se permiten Creditos o Debitos'  AS message, NULL AS mov_id; LEAVE main;
            END IF;
        ELSE
            ROLLBACK; SELECT 1 AS status_code, 'Producto enviado no existe'  AS message, NULL AS mov_id; LEAVE main;
        END IF;

        /* Insert movimiento DESTINO */
        INSERT INTO movimiento_general
        (mov_producto_id, mov_id_causa, mov_id_naturaleza, mov_id_canal, mov_id_estado,
         mov_id_moneda, mov_monto, mov_saldo_antes, mov_saldo_despues,
         mov_contraparte_tipo, mov_contraparte_id, mov_contraparte_numero, mov_contraparte_banco,
         mov_referencia_externa, mov_detalle, mov_usuario_registra)
        VALUES
        (p_destino_id, v_id_causa_destino, v_id_nat_destino, v_id_canal, v_id_estado,
         v_id_moneda_dest, p_monto, v_saldo_antes_d, v_saldo_desp_d,
         v_id_tp_origen, p_origen_id, NULL, NULL,
         p_referencia, CONCAT('[DESTINO] ', p_detalle), p_usuario_registra);

        SET v_mov_id_destino = LAST_INSERT_ID();
    END IF;

    COMMIT;

    -- Respuesta
    IF p_operacion='MOV' THEN
        SELECT 0 AS status_code, 'Movimiento registrado (MOV).' AS message, v_mov_id_origen AS mov_id;
    ELSE
        SELECT 0 AS status_code, 'Transferencia registrada (TRX).' AS message, v_mov_id_destino AS mov_id;
    END IF;

END $$
DELIMITER ;
