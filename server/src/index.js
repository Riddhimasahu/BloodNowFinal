import './loadEnv.js';

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';

import { pool } from './db/pool.js';
import authRoutes from './routes/auth.js';
import bankRoutes from './routes/banks.js';
import searchRoutes from './routes/search.js';
import userRoutes from './routes/users.js';
import analyticsRoutes from './routes/analytics.js';
import sosRoutes from './routes/sos.js';
import { initFirebase } from './utils/firebaseSetup.js';

const app = express();
const port = Number(process.env.PORT) || 3000;

app.use(helmet());
app.use(
  cors({
    origin: true,
    credentials: true,
  }),
);
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'blood-now-api' });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/banks', bankRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/sos-request', sosRoutes);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

async function start() {
  const dbUrl = process.env.DATABASE_URL?.trim();
  if (!dbUrl) {
    console.error('');
    console.error('FATAL: DATABASE_URL is not set.');
    console.error('  1. Copy server/.env.example to server/.env');
    console.error('  2. Set DATABASE_URL=postgresql://USER:PASSWORD@localhost:5432/bloodnow');
    console.error('  3. Create DB: createdb bloodnow');
    console.error('  4. Run: psql %DATABASE_URL% -f db/schema.sql (from server folder)');
    console.error('');
    process.exit(1);
  }

  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    await client.query(`
      CREATE TABLE IF NOT EXISTS unfulfilled_searches (
        id BIGSERIAL PRIMARY KEY,
        blood_group VARCHAR(8) NOT NULL,
        latitude DOUBLE PRECISION,
        longitude DOUBLE PRECISION,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    try {
      await client.query('ALTER TABLE users ADD CONSTRAINT users_phone_key UNIQUE (phone)');
    } catch(err) {
      if (err.code !== '42P07' && err.code !== '42710') {
         // ignore relation already exists error
      }
    }
    try {
      await client.query('ALTER TABLE users ADD COLUMN fcm_token VARCHAR(255)');
    } catch(err) {
      // ignore
    }
    await client.query(`
      CREATE TABLE IF NOT EXISTS sos_requests (
        id BIGSERIAL PRIMARY KEY,
        requester_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
        blood_group VARCHAR(8) NOT NULL,
        latitude DOUBLE PRECISION NOT NULL,
        longitude DOUBLE PRECISION NOT NULL,
        status VARCHAR(50) NOT NULL DEFAULT 'pending',
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    client.release();
    console.log('PostgreSQL: connected & schemas verified');
  } catch (e) {
    console.error('');
    console.error('FATAL: Cannot connect to PostgreSQL.');
    console.error('  Message:', e.message);
    console.error('  Check server/.env DATABASE_URL, PostgreSQL service, and that database "bloodnow" exists.');
    console.error('');
    process.exit(1);
  }

  if (!process.env.JWT_SECRET?.trim()) {
    console.warn(
      'Warning: JWT_SECRET is missing or empty. Set it in server/.env before production.',
    );
  }

  initFirebase();

  app.listen(3000, '0.0.0.0', () => {
    console.log(`Blood Now API listening on http://0.0.0.0:${3000}`);
  });
}

start();
