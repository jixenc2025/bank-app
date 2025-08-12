import { Router } from 'express';
import { body } from 'express-validator';
import { auth } from '../middleware/auth.js';
import { movement, transfer } from '../controllers/transfers.controller.js';

const router = Router();

const common = [
  body('origen_tipo_valor').isIn(['1','2','3']),
  body('origen_id').isInt({ min: 1 }),
  body('origen_moneda_valor').isIn(['0','1']),
  body('monto').isFloat({ gt: 0 }),
  body('causa_origen_valor').trim().isLength({ min: 3, max: 10 }),
  body('naturaleza_origen').isIn(['CR','DB']),
  body('referencia').trim().isLength({ min: 3, max: 50 }),
  body('detalle').trim().isLength({ min: 3, max: 255 })
];

router.post('/movement', auth, common, movement);

router.post('/transfer', auth, [
  ...common,
  body('destino_tipo_valor').isIn(['1','2','3']),
  body('destino_id').isInt({ min: 1 }),
  body('destino_moneda_valor').isIn(['0','1']),
  body('causa_destino_valor').trim().isLength({ min: 3, max: 10 }),
  body('naturaleza_destino').isIn(['CR','DB'])
], transfer);

export default router;
