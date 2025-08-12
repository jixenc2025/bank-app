import { validationResult } from 'express-validator';
import { callSP } from '../utils/sp.js';

export async function transfer(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const {
      origen_tipo_valor, origen_id, origen_moneda_valor, monto,
      causa_origen_valor, naturaleza_origen,
      destino_tipo_valor, destino_id, destino_moneda_valor,
      causa_destino_valor, naturaleza_destino,
      referencia, detalle
    } = req.body;

    const params = [
      'TRX',
      origen_tipo_valor, origen_id, origen_moneda_valor, monto, causa_origen_valor, naturaleza_origen,
      destino_tipo_valor, destino_id, destino_moneda_valor, causa_destino_valor, naturaleza_destino,
      'APP', 'APR', referencia, detalle, `uid:${req.user.id}`
    ];

    const rows = await callSP('sp_registrar_transaccion', params);
    const meta = rows?.[0]?.[0];
    res.status(meta?.status_code === 0 ? 201 : 400).json(meta ?? { error: 'trx_failed' });
  } catch (e) { next(e); }
}

export async function movement(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const {
      origen_tipo_valor, origen_id, origen_moneda_valor, monto,
      causa_origen_valor, naturaleza_origen, referencia, detalle
    } = req.body;

    const params = [
      'MOV',
      origen_tipo_valor, origen_id, origen_moneda_valor, monto, causa_origen_valor, naturaleza_origen,
      null, null, null, null, null,
      'APP', 'APR', referencia, detalle, `uid:${req.user.id}`
    ];

    const rows = await callSP('sp_registrar_transaccion', params);
    const meta = rows?.[0]?.[0];
    res.status(meta?.status_code === 0 ? 201 : 400).json(meta ?? { error: 'mov_failed' });
  } catch (e) { next(e); }
}
