USE db_genesisapp;
/*-----------------------------
   CATALOGOS
  ---------------------------*/
-- Estados de usuario
INSERT INTO catalogo (cat_tipo_catalogo, cat_valor, cat_descripcion) VALUES
('estado_usuario','A','Activo'),
('estado_usuario','I','Inactivo/Baja');

-- Monedas
INSERT INTO catalogo (cat_tipo_catalogo, cat_valor, cat_descripcion) VALUES
('moneda','0','Quetzal'),
('moneda','1','Dólar estadounidense');

-- Estados de producto
INSERT INTO catalogo (cat_tipo_catalogo, cat_valor, cat_descripcion) VALUES
('estado_producto','ACT','Activo'),
('estado_producto','BLOQ','Bloqueado'),
('estado_producto','EMBR','Embargado'),
('estado_producto','CANC','Cancelado');

-- Tipo de producto (para "mov_contraparte_tipo" en movimiento_general)
INSERT INTO catalogo (cat_tipo_catalogo, cat_valor, cat_descripcion) VALUES
('tipo_producto','1','Cuenta de Ahorro'),
('tipo_producto','2','Cuenta Monetaria'),
('tipo_producto','3','Tarjeta de Crédito');

-- Naturaleza del movimiento
INSERT INTO catalogo (cat_tipo_catalogo, cat_valor, cat_descripcion) VALUES
('naturaleza_mov','CR','Credito'),
('naturaleza_mov','DB','Debito');

-- Causas (tu “número de causa”)
-- causa creada por la cadena Moneda, producto, tipo
INSERT INTO catalogo (cat_tipo_catalogo, cat_valor, cat_descripcion) VALUES
('tipo_causa_mov','01010','Credito GTQ ahorros'), 
('tipo_causa_mov','11010','Credito USD ahorros'),
('tipo_causa_mov','01020','Debito GTQ ahorros'), 
('tipo_causa_mov','11020','Debito USD ahorros'),

('tipo_causa_mov','02010','Credito GTQ monetarios'), 
('tipo_causa_mov','12010','Credito USD monetarios'),
('tipo_causa_mov','02020','Debito GTQ monetarios'), 
('tipo_causa_mov','12020','Debito USD monetarios'),

('tipo_causa_mov','03010','Credito GTQ TC'), 
('tipo_causa_mov','13010','Credito USD TC'),
('tipo_causa_mov','03020','Debito GTQ TC'), 
('tipo_causa_mov','13020','Debito USD TC');

-- Canal de operación
INSERT INTO catalogo (cat_tipo_catalogo, cat_valor, cat_descripcion) VALUES
('canal_mov','APP','App movil'),
('canal_mov','WEB','Web'),
('canal_mov','AGE','Agencia');

-- Estado del movimiento
INSERT INTO catalogo (cat_tipo_catalogo, cat_valor, cat_descripcion) VALUES
('estado_movimiento','PEND','Pendiente'),
('estado_movimiento','APR','Aprovado'),
('estado_movimiento','REV','Reversado');
