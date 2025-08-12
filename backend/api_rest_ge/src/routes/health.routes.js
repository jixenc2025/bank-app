// src/routes/health.routes.js
import { Router } from 'express';
import { pool } from '../db.js';
const router = Router();
router.get('/', async (_req, res, next) => {
  try { const [r] = await pool.query('SELECT NOW() AS now'); res.json({ ok: true, dbTime: r[0].now }); }
  catch (e) { next(e); }
});
export default router;

