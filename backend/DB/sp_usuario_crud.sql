DROP PROCEDURE IF EXISTS sp_usuario_crud;
DELIMITER $$


/**
 * sp_usuario_crud
 * CRUD con baja lógica para la tabla `usuario`.
 *
 * p_operacion:
 *   - 'CREATE' : crea un usuario nuevo.
 *   - 'READ'   : consulta usuario por id, alias o por email.
 *   - 'UPDATE' : actualiza datos.
 *   - 'DELETE' : baja lógica -> estado 'I' en catalogo.estado_usuario.
 * SP creado por: Jhonathan Ixen
 */
 
CREATE PROCEDURE sp_usuario_crud(
    IN  p_operacion         CHAR(1),
    IN  p_usr_id            INT,
    IN  p_usr_nombres       VARCHAR(100),
    IN  p_usr_apellidos     VARCHAR(100),
    IN  p_usr_alias         VARCHAR(50),
    IN  p_usr_email         VARCHAR(100),
    IN  p_usr_contrasena    VARCHAR(255),
    IN  p_estado_valor      CHAR(1)          -- 'A' o 'I' (para A/C/D)
)
main: BEGIN
    DECLARE v_estado_id_A   INT;
    DECLARE v_estado_id_I   INT;
    DECLARE v_estado_id_set INT;
    DECLARE v_now           TIMESTAMP;
    DECLARE v_exists_id     INT DEFAULT 0;
    DECLARE v_exists_email  INT DEFAULT 0;
    DECLARE v_usr_id_out    INT DEFAULT NULL;

    -- IDs de estado A/I desde catalogo
    SET v_estado_id_A = (SELECT cat_id_catalogo FROM catalogo 
                         WHERE cat_tipo_catalogo='estado_usuario' AND cat_valor='A' LIMIT 1);
    SET v_estado_id_I = (SELECT cat_id_catalogo FROM catalogo 
                         WHERE cat_tipo_catalogo='estado_usuario' AND cat_valor='I' LIMIT 1);

    SET v_now = NOW();

    START TRANSACTION;

    CASE UPPER(IFNULL(p_operacion,''))

        /* ================= A: ALTA ================= */
        WHEN 'A' THEN
            IF p_usr_email IS NULL OR p_usr_contrasena IS NULL 
               OR p_usr_nombres IS NULL OR p_usr_apellidos IS NULL THEN
                ROLLBACK;
                SELECT 1 AS status_code, 'Faltan datos (nombres, apellidos, email, contraseña).' AS message, NULL AS usuario_id;
                LEAVE main;
            END IF;

            SELECT COUNT(*) INTO v_exists_email FROM usuario WHERE usr_email = p_usr_email;
            IF v_exists_email > 0 THEN
                ROLLBACK;
                SELECT 1 AS status_code, 'El email ya está registrado.' AS message, NULL AS usuario_id;
                LEAVE main;
            END IF;

            -- Estado por defecto A si no viene
            SET v_estado_id_set = IFNULL(
                (SELECT cat_id_catalogo FROM catalogo 
                 WHERE cat_tipo_catalogo='estado_usuario' AND cat_valor=IFNULL(p_estado_valor,'A') LIMIT 1),
                v_estado_id_A
            );

            INSERT INTO usuario
            (usr_nombres, usr_apellidos, usr_alias, usr_email, usr_contrasena_hash,
             usr_id_estado_usuario, usr_fecha_creacion)
            VALUES
            (p_usr_nombres, p_usr_apellidos, p_usr_alias, p_usr_email, p_usr_contrasena,
             v_estado_id_set, v_now);

            SET v_usr_id_out = LAST_INSERT_ID();
            COMMIT;
            SELECT 0 AS status_code, 'Usuario creado correctamente.' AS message, v_usr_id_out AS usuario_id;
            LEAVE main;

        /* ================= B: BUSCAR ================= */
        WHEN 'B' THEN
            IF p_usr_id IS NULL AND p_usr_email IS NULL THEN
                ROLLBACK;
                SELECT 1 AS status_code, 'Indique usr_id o email para consultar.' AS message, NULL AS usuario_id;
                LEAVE main;
            END IF;

            IF p_usr_id IS NOT NULL THEN
                SELECT COUNT(*) INTO v_exists_id FROM usuario WHERE usr_id_usuario = p_usr_id;
                IF v_exists_id = 0 THEN
                    ROLLBACK;
                    SELECT 2 AS status_code, 'Usuario no encontrado por id.' AS message, NULL AS usuario_id;
                    LEAVE main;
                END IF;
                SET v_usr_id_out = p_usr_id;
                COMMIT;
                SELECT 0 AS status_code, 'OK' AS message, v_usr_id_out AS usuario_id;
                SELECT u.*
                FROM usuario u
                WHERE u.usr_id_usuario = p_usr_id;
                LEAVE main;
            ELSE
                SELECT usr_id_usuario INTO v_usr_id_out
                FROM usuario WHERE usr_email = p_usr_email LIMIT 1;
                IF v_usr_id_out IS NULL THEN
                    ROLLBACK;
                    SELECT 2 AS status_code, 'Usuario no encontrado por email.' AS message, NULL AS usuario_id;
                    LEAVE main;
                END IF;
                COMMIT;
                SELECT 0 AS status_code, 'OK' AS message, v_usr_id_out AS usuario_id;
                SELECT u.*
                FROM usuario u
                WHERE u.usr_email = p_usr_email;
                LEAVE main;
            END IF;

        /* ================= C: CAMBIAR ================= */
        WHEN 'C' THEN
            IF p_usr_id IS NULL THEN
                ROLLBACK;
                SELECT 1 AS status_code, 'Indique usr_id para actualizar.' AS message, NULL AS usuario_id;
                LEAVE main;
            END IF;

            SELECT COUNT(*) INTO v_exists_id FROM usuario WHERE usr_id_usuario = p_usr_id;
            IF v_exists_id = 0 THEN
                ROLLBACK;
                SELECT 2 AS status_code, 'Usuario no existe para actualizar.' AS message, NULL AS usuario_id;
                LEAVE main;
            END IF;

            -- Validar email único si se cambia
            IF p_usr_email IS NOT NULL THEN
                SELECT COUNT(*) INTO v_exists_email
                FROM usuario
                WHERE usr_email = p_usr_email AND usr_id_usuario <> p_usr_id;
                IF v_exists_email > 0 THEN
                    ROLLBACK;
                    SELECT 1 AS status_code, 'El email indicado ya pertenece a otro usuario.' AS message, NULL AS usuario_id;
                    LEAVE main;
                END IF;
            END IF;

            -- Resolver estado si se manda p_estado_valor
            SET v_estado_id_set = (SELECT cat_id_catalogo FROM catalogo
                                   WHERE cat_tipo_catalogo='estado_usuario' AND cat_valor=p_estado_valor LIMIT 1);

            UPDATE usuario
            SET
                usr_nombres            = COALESCE(p_usr_nombres, usr_nombres),
                usr_apellidos          = COALESCE(p_usr_apellidos, usr_apellidos),
                usr_alias              = COALESCE(p_usr_alias, usr_alias),
                usr_email              = COALESCE(p_usr_email, usr_email),
                usr_contrasena_hash    = COALESCE(p_usr_contrasena, usr_contrasena_hash),
                usr_id_estado_usuario  = COALESCE(v_estado_id_set, usr_id_estado_usuario),
                usr_fecha_modificacion = v_now
            WHERE usr_id_usuario = p_usr_id;

            SET v_usr_id_out = p_usr_id;
            COMMIT;
            SELECT 0 AS status_code, 'Usuario actualizado correctamente.' AS message, v_usr_id_out AS usuario_id;
            LEAVE main;

        /* ================= D: DAR DE BAJA ================= */
        WHEN 'D' THEN
            IF p_usr_id IS NULL THEN
                ROLLBACK;
                SELECT 1 AS status_code, 'Indique usr_id para dar de baja.' AS message, NULL AS usuario_id;
                LEAVE main;
            END IF;

            SELECT COUNT(*) INTO v_exists_id FROM usuario WHERE usr_id_usuario = p_usr_id;
            IF v_exists_id = 0 THEN
                ROLLBACK;
                SELECT 2 AS status_code, 'Usuario no existe para baja lógica.' AS message, NULL AS usuario_id;
                LEAVE main;
            END IF;

            UPDATE usuario
            SET usr_id_estado_usuario = v_estado_id_I,
                usr_fecha_modificacion = v_now
            WHERE usr_id_usuario = p_usr_id;

            SET v_usr_id_out = p_usr_id;
            COMMIT;
            SELECT 0 AS status_code, 'Usuario dado de baja (estado I).' AS message, v_usr_id_out AS usuario_id;
            LEAVE main;

        ELSE
            ROLLBACK;
            SELECT 1 AS status_code, 'Operación inválida.' AS message, NULL AS usuario_id;
            LEAVE main;
    END CASE;
END $$
DELIMITER ;

