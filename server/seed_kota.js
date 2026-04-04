import fs from 'fs';
import pg from 'pg';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const sql = fs.readFileSync(join(__dirname, 'db', 'seed_kota.sql'), 'utf-8');

pool.query(sql).then(() => {
  console.log('Kota Seed applied successfully!');
  pool.end();
  process.exit(0);
}).catch(err => {
  console.error('Error applying seed:', err);
  pool.end();
  process.exit(1);
});
