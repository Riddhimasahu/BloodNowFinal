import pg from 'pg';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
import bcrypt from 'bcryptjs';
const NEW_HASH = bcrypt.hashSync('bloodbank123', 10);

async function updatePasswords() {
  try {
    const res = await pool.query('UPDATE blood_banks SET password_hash = $1', [NEW_HASH]);
    console.log(`Successfully updated ${res.rowCount} blood banks with the default password hash!`);
  } catch (err) {
    console.error('Error updating passwords:', err);
  } finally {
    pool.end();
  }
}

updatePasswords();
