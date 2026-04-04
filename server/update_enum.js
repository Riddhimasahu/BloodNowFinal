import pg from 'pg';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

async function updateSchema() {
  try {
    await pool.query(`ALTER TABLE appointments DROP CONSTRAINT IF EXISTS status_chk;`);
    await pool.query(`ALTER TABLE appointments ADD CONSTRAINT status_chk CHECK (status IN ('pending', 'confirmed', 'donated', 'completed', 'cancelled', 'no_show'));`);
    console.log('Successfully updated status constraints on appointments table!');
  } catch (err) {
    console.error('Failed to update constraints:', err);
  } finally {
    pool.end();
  }
}

updateSchema();
