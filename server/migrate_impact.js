import { pool } from './src/db/pool.js';

async function migrate() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS impact_events (
        id              BIGSERIAL PRIMARY KEY,
        user_id         BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
        blood_bank_id   BIGINT NOT NULL REFERENCES blood_banks (id) ON DELETE CASCADE,
        donation_id     BIGINT NOT NULL REFERENCES appointments (id) ON DELETE CASCADE,
        created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);
    console.log('Successfully created impact_events table!');
  } catch (err) {
    console.error('Migration failed:', err);
  } finally {
    client.release();
    process.exit(0);
  }
}

migrate();
