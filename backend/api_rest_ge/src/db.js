import mysql from 'mysql2/promise';

export const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  connectionLimit: 10,
  multipleStatements: false
});

export async function testDB() {
  const conn = await pool.getConnection();
  try {
    await conn.ping();
    console.log('Conexión exitosa');
  } finally {
    conn.release();
  }
}

