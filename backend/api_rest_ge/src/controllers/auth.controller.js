import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { validationResult } from 'express-validator';
import { callSP } from '../utils/sp.js';

const signAccess  = (payload) => jwt.sign(payload, process.env.JWT_SECRET,         { expiresIn: process.env.JWT_EXPIRES });
const signRefresh = (payload) => jwt.sign(payload, process.env.JWT_REFRESH_SECRET, { expiresIn: process.env.JWT_REFRESH_EXPIRES });

export async function register(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { nombres, apellidos, alias, email, password } = req.body;
    const hash = await bcrypt.hash(password, 10);

    // Ajusta al orden esperado por tu SP sp_usuario_crud
    const rows = await callSP('sp_usuario_crud', ['A', null, nombres, apellidos, alias ?? null, email, hash, 'A']);
    const meta = rows?.[0]?.[0];
    if (!meta || meta.status_code !== 0) return res.status(400).json(meta ?? { error: 'create_failed' });

    const accessToken  = signAccess({ id: meta.usuario_id, email });
    const refreshToken = signRefresh({ id: meta.usuario_id, email });
    res.status(201).json({ accessToken, refreshToken, userId: meta.usuario_id });
  } catch (e) { next(e); }
}

export async function login(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { email, password } = req.body;

    const rows = await callSP('sp_usuario_crud', ['B', null, null, null, null, email, null, null]);
    const meta = rows?.[0]?.[0];
    if (!meta || meta.status_code !== 0) return res.status(400).json(meta ?? { error: 'user_not_found' });

    const u = rows?.[1]?.[0]; // usr_contrasena_hash, usr_id_usuario, usr_email
    const ok = u && await bcrypt.compare(password, u.usr_contrasena_hash);
    if (!ok) return res.status(401).json({ error: 'invalid_credentials' });

    const accessToken  = signAccess({ id: u.usr_id_usuario, email: u.usr_email });
    const refreshToken = signRefresh({ id: u.usr_id_usuario, email: u.usr_email });
    res.json({ accessToken, refreshToken, userId: u.usr_id_usuario });
  } catch (e) { next(e); }
}

export async function refreshToken(req, res) {
  const { refreshToken } = req.body;
  if (!refreshToken) return res.status(400).json({ error: 'missing_refresh_token' });

  try {
    const payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const newAccess  = signAccess({ id: payload.id, email: payload.email });
    const newRefresh = signRefresh({ id: payload.id, email: payload.email }); // rotación simple
    res.json({ accessToken: newAccess, refreshToken: newRefresh });
  } catch {
    res.status(401).json({ error: 'invalid_refresh_token' });
  }
}

export async function me(req, res) {
  res.json({ id: req.user.id, email: req.user.email });
}
