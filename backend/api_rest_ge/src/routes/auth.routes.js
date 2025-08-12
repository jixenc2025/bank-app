import { Router } from 'express';
import { body } from 'express-validator';
import { register, login, refreshToken, me } from '../controllers/auth.controller.js';
import { auth } from '../middleware/auth.js';

const router = Router();

router.post('/register', [
  body('nombres').trim().isLength({ min: 2 }).bail(),
  body('apellidos').trim().isLength({ min: 2 }).bail(),
  body('email').trim().isEmail().normalizeEmail().bail(),
  body('password')
    .isStrongPassword({ minLength: 8, minLowercase: 1, minUppercase: 1, minNumbers: 1, minSymbols: 0 })
    .withMessage('La contraseña debe tener 8+ caracteres, mayúscula, minúscula y número.')
    .bail(),
  body('alias').optional().trim().isLength({ max: 50 })
], register);

router.post('/login', [
  body('email').trim().isEmail().normalizeEmail().bail(),
  body('password').isLength({ min: 6 })
], login);

router.post('/refresh', [
  body('refreshToken').isString().isLength({ min: 20 })
], refreshToken);

router.get('/me', auth, me);

export default router;
