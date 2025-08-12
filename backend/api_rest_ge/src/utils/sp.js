import { pool } from '../db.js';

export async function callSP(spName, params = []) {
  const placeholders = params.map(() => '?').join(',');
  const sql = `CALL ${spName}(${placeholders})`;
  const [rows] = await pool.query(sql, params);
  return rows; // mysql2 retorna array de resultsets
}
