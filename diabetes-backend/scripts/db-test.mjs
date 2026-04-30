import { pool } from '../src/config/db.js';

try {
  const [rows] = await pool.query('SELECT DATABASE() AS db, NOW() AS now');
  console.log('Connected to DB:', rows[0]);
  const [t] = await pool.query('SHOW TABLES');
  console.log('Tables:', t.map(r => Object.values(r)[0]));
  process.exit(0);
} catch (e) {
  console.error('DB Error:', e.message);
  process.exit(1);
}
