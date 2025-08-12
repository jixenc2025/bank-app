import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { sanitizeBodyAndParams } from './middleware/sanitize.js';
import { testDB, pool } from './db.js';
// Rutas
import authRoutes from './routes/auth.routes.js';
import transferRoutes from './routes/transfers.routes.js';
import healthRoutes from './routes/health.routes.js'; // opcional

const app = express();

// Seguridad / middlewares base
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN?.split(',') || true }));
app.use(express.json({ limit: '100kb' }));
app.use(sanitizeBodyAndParams);

// Rate limit solo en auth
app.use('/api/auth', rateLimit({ windowMs: 15 * 60 * 1000, max: 30 }));

// Endpoint de prueba simple (DB)
app.get('/ping', async (_req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT 1 AS result');
    res.json(rows[0]);
  } catch (err) { next(err); }
});

// Montaje de rutas de la API
app.use('/api/health', healthRoutes);        // GET /api/health
app.use('/api/auth', authRoutes);            // POST /api/auth/register, /login
app.use('/api/transfers', transferRoutes);   // POST /api/transfers/movement, /transfer

// 404 para rutas no existentes
app.use((req, res) => {
  res.status(404).json({ error: 'not_found', path: req.originalUrl });
});

// Manejador de errores
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'internal_error' });
});

// Arranque
const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, async () => {
  await testDB();
  console.log(`API corriendo en http://localhost:${PORT}`);
});
