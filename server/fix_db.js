import dotenv from 'dotenv';
import pg from 'pg';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

async function fix() {
  try {
    await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS credits INTEGER NOT NULL DEFAULT 0;`);
    console.log('Column credits added to users successfully.');
  } catch (e) {
    console.error('Error:', e);
  } finally {
    await pool.end();
  }
}
fix();
