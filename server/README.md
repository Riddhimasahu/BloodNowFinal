# Blood Now API

Node.js + Express + PostgreSQL backend for registration, auth, blood bank operations, and nearest-neighbor search (Haversine).

## Prerequisites

- [Node.js](https://nodejs.org/) 20+
- [PostgreSQL](https://www.postgresql.org/download/) 14+

## Setup

1. Create database:

   ```bash
   createdb bloodnow
   ```

2. Apply schema and optional seed data (from the `server` folder):

   ```bash
   psql %DATABASE_URL% -f db/schema.sql
   psql %DATABASE_URL% -f db/seed.sql
   ```

   Or set `DATABASE_URL` first, e.g. `postgresql://postgres:postgres@localhost:5432/bloodnow`.

3. Configure environment:

   ```bash
   copy .env.example .env
   ```

   Edit `server/.env`: set `DATABASE_URL` to your real PostgreSQL user and password, e.g.  
   `postgresql://postgres:YOUR_PASSWORD@localhost:5432/bloodnow`  
   The API loads this file from the `server` folder even if you start Node from another directory.

   On startup the server runs `SELECT 1`. If the DB is unreachable, it exits with a clear error instead of failing only at registration.

4. Install and run:

   ```bash
   npm install
   npm run dev
   ```

   API: `http://127.0.0.1:3000` (see `/health`).

## JWT

- **User** tokens include `typ: "user"` and `sub` = user id.
- **Blood bank** tokens include `typ: "bank"` and `sub` = blood bank id.
- Send `Authorization: Bearer <token>` for protected routes.

## Search algorithm

- **Nearest blood banks** and **nearest donors** use [Haversine](https://en.wikipedia.org/wiki/Haversine_formula) great-circle distance (meters).
- **Requester-style** bank search: pass `bloodGroup` so only banks with `units_available > 0` for that group are returned (still ordered by distance).
- **Nearest donors** requires a **user** JWT; results exclude the caller, mask phone digits, and round coordinates (~110 m) for privacy.

## Mobile / emulator base URL

- Android emulator: `http://10.0.2.2:3000`
- iOS simulator: `http://127.0.0.1:3000`
- Physical device: use your PC’s LAN IP, e.g. `http://192.168.1.10:3000`

Pass to Flutter as: `flutter run --dart-define=API_BASE_URL=http://...`

## API summary

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/auth/register` | — | Register user |
| POST | `/api/auth/login` | — | User login → JWT |
| GET | `/api/users/me` | User | Current user profile |
| PATCH | `/api/users/me` | User | Update profile, location, share flag |
| POST | `/api/users/me/password` | User | Change password |
| POST | `/api/banks/register` | — | Register blood bank (lat/lng required) |
| POST | `/api/banks/login` | — | Bank login → JWT |
| GET | `/api/banks/me` | Bank | Centre profile |
| PATCH | `/api/banks/me` | Bank | Update centre / site location |
| POST | `/api/banks/me/password` | Bank | Change password |
| GET | `/api/banks/me/inventory` | Bank | All 8 blood groups + units |
| PUT | `/api/banks/me/inventory` | Bank | Body `{ "units": { "A+": 5, ... } }` partial update |
| GET | `/api/search/nearest-banks` | — | `?lat=&lng=&bloodGroup?=&limit=` |
| GET | `/api/search/nearest-donors` | **User** | `?lat=&lng=&bloodGroup=&limit=` |

Seed blood banks (after `seed.sql`) use password `DemoBank!123` if you log in as a bank with those emails.
