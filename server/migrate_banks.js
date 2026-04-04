import pg from 'pg';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, '.env') });

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

async function migrate() {
  try {
    // 1. Add columns to users table
    await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(50) NOT NULL DEFAULT 'user';`);
    await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS blood_bank_id BIGINT;`);

    // 2. Fetch blood banks
    const { rows: banks } = await pool.query('SELECT * FROM blood_banks;');
    
    const hash = await bcrypt.hash('bloodbank123', 10);
    let migratedCount = 0;

    for (const bank of banks) {
      // Check if user already exists
      const { rows: existing } = await pool.query('SELECT id FROM users WHERE email = $1', [bank.email]);
      if (existing.length === 0) {
        // We'll set a default blood_group since the schema requires it for users
        // 'O+' is a safe placeholder, or they can update it (though banks don't have blood groups)
        await pool.query(
          `INSERT INTO users (
            email, phone, password_hash, full_name, blood_group, address_line, 
            latitude, longitude, role, blood_bank_id
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            bank.email, 
            bank.phone, 
            hash, 
            bank.name, 
            'O+', // placeholder
            bank.address_line,
            bank.latitude,
            bank.longitude,
            'blood_bank',
            bank.id
          ]
        );
        migratedCount++;
      } else {
        // Update existing just in case
        await pool.query(
          `UPDATE users SET role = 'blood_bank', blood_bank_id = $1, password_hash = $2 WHERE email = $3`,
          [bank.id, hash, bank.email]
        );
        migratedCount++;
      }
    }
    
    console.log(`Migration complete. Generated/updated ${migratedCount} bank user records.`);
  } catch (err) {
    console.error('Migration failed:', err);
  } finally {
    pool.end();
  }
}

migrate();
