// src/config/db.js
import mysql from 'mysql2/promise';

export const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASS || 'Alvi8909!',
  database: process.env.DB_NAME || 'diabetes',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

export default pool; // <-- add this line

export async function testConnection() {
  try {
    const [rows] = await pool.query('SELECT 1 AS ok');
    console.log('✅ DB connection OK:', rows);
  } catch (err) {
    console.error('❌ DB connection failed:', err.message);
  }
}
