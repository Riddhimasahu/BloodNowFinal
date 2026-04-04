import pg from 'pg';

import '../loadEnv.js';

const { Pool } = pg;

if (!process.env.DATABASE_URL?.trim()) {
  console.warn(
    'DATABASE_URL is empty. Create server/.env from .env.example with your PostgreSQL connection string.',
  );
}

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL ,
  // ssl: {
  //   rejectUnauthorized: false
  // },
  max: 12,
  idleTimeoutMillis: 30_000,
});
