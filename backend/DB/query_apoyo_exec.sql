/**
EJEMPLOS USUARIOS

 */

-- A: Alta (crear)
CALL sp_usuario_crud(
  'A',
  NULL,
  'Juan', 'Pérez Gómez', 'juanpg',
  'juan@example.com',
  '$2b$10$HASHJUAN',
  'A'
);

-- B: Buscar por id
CALL sp_usuario_crud('B', 1, NULL, NULL, NULL, NULL, NULL, NULL);

-- B: Buscar por email
CALL sp_usuario_crud('B', NULL, NULL, NULL, NULL, 'juan@example.com', NULL, NULL);

-- C: Cambiar (solo lo no-NULL se actualiza)
CALL sp_usuario_crud(
  'C',
  1,
  'Juan Carlos', NULL, 'jcarlo',
  'juan.c@example.com',
  NULL,
  'A'
);

-- D: Dar de baja (estado I)
CALL sp_usuario_crud('D', 1, NULL, NULL, NULL, NULL, NULL, 'I');

/**
EJEMPLOS TRANSACCIONES
 */


-- 1) Depósito a ahorro GTQ (CR)  [tipo=1 ahorro]
CALL sp_registrar_transaccion(
  '1',                                    -- tipo_producto: ahorro
  (SELECT aho_id FROM cuenta_ahorro WHERE aho_numero_cuenta='1002003001'),
  '0',                                    -- moneda GTQ
  250.00,
  '01010',                                -- causa (tu codificación)
  'CR',                                   -- naturaleza
  'APP', 'APR',
  'DEP-20250812-0001',
  'Depósito en app',
  'system',
  NULL, NULL, NULL, NULL                  -- sin contraparte
);

-- 2) Retiro de monetaria GTQ (DB) con sobregiro permitido  [tipo=2 monetaria]
CALL sp_registrar_transaccion(
  '2',
  (SELECT mon_id FROM cuenta_monetaria WHERE mon_numero_cuenta='1002003002'),
  '0',
  120.00,
  '02020',
  'DB',
  'WEB', 'APR',
  'RET-20250812-0001',
  'Pago de servicios',
  'system',
  NULL, NULL, NULL, NULL
);

-- 3) Compra con tarjeta USD (DB)  [tipo=3 tarjeta]
CALL sp_registrar_transaccion(
  '3',
  (SELECT tarj_id FROM tarjeta_credito WHERE tarj_numero_tarjeta='411111******1111'),
  '1',
  80.00,
  '13020',
  'DB',
  'APP', 'APR',
  'COMPRA-20250812-0001',
  'Compra en tienda',
  'system',
  NULL, NULL, NULL, NULL
);

-- 4) Transferencia Ahorro Juan -> Ahorro María (dos asientos con misma referencia)
SET @REF := 'TRX-20250812-0002';

-- 4a) Débito en origen
CALL sp_registrar_transaccion(
  '1',
  (SELECT aho_id FROM cuenta_ahorro WHERE aho_numero_cuenta='1002003001'),
  '0',
  200.00,
  '01020',       -- tu causa de débito ahorro GTQ
  'DB',
  'APP', 'APR',
  @REF,
  'Transferencia a ahorro María',
  'system',
  '1', (SELECT aho_id FROM cuenta_ahorro WHERE aho_numero_cuenta='2003004001'), '2003004001', NULL
);

-- 4b) Crédito en destino
CALL sp_registrar_transaccion(
  '1',
  (SELECT aho_id FROM cuenta_ahorro WHERE aho_numero_cuenta='2003004001'),
  '0',
  200.00,
  '01010',       -- tu causa de crédito ahorro GTQ
  'CR',
  'APP', 'APR',
  @REF,
  'Transferencia recibida de ahorro Juan',
  'system',
  '1', (SELECT aho_id FROM cuenta_ahorro WHERE aho_numero_cuenta='1002003001'), '1002003001', NULL
);




-- ejemplo retiro monetaria GTQ
CALL sp_registrar_transaccion(
  'MOV',
  '2', (SELECT mon_id FROM cuenta_monetaria WHERE mon_numero_cuenta='1002003002'), '0',
  120.00, '02020', 'DB',
  NULL, NULL, NULL, NULL, NULL,           -- destino no aplica
  'APP', 'APR', 'RET-20250812-0001', 'Pago de servicios', 'system'
);

-- ejemplo Transferencia a tercero (Ahorro → Tarjeta  GTQ):
SET @REF := 'TRX-20250812-0007';
CALL sp_registrar_transaccion(
  'TRX',
  -- ORIGEN (Ahorro Juan)
  '1', (SELECT aho_id FROM cuenta_ahorro WHERE aho_numero_cuenta='1002003001'), '0',
  200.00, '01020', 'DB',                  -- causa/naturaleza ORIGEN (débito ahorro GTQ)
  -- DESTINO (Tarjeta María)
  '3', (SELECT tarj_id FROM tarjeta_credito WHERE tarj_numero_tarjeta='411111******1111'), '0',
  '03010', 'CR',                          -- causa/naturaleza DESTINO (crédito tarjeta GTQ = pago)
  -- Metadatos
  'APP', 'APR', @REF, 'Pago a TC de tercero', 'system'
);


-- ejemplo Transferencia entre cuentas internas (Monetaria → Ahorro, USD):
SET @REF := 'TRX-20250812-0008';
CALL sp_registrar_transaccion(
  'TRX',
  '2', (SELECT mon_id FROM cuenta_monetaria WHERE mon_numero_cuenta='XMONUSD'), '1',
  75.00, '12020', 'DB',                   -- débito monetaria USD
  '1', (SELECT aho_id FROM cuenta_ahorro WHERE aho_numero_cuenta='XAHOUSD'), '1',
  '11010', 'CR',                          -- crédito ahorro USD
  'WEB', 'APR', @REF, 'Trx interna USD', 'system'
);
