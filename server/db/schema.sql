-- Blood Now — core schema (PostgreSQL)
-- Run: psql "%DATABASE_URL%" -f db/schema.sql   (Windows: set DATABASE_URL first)

CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE IF NOT EXISTS users (
  id              BIGSERIAL PRIMARY KEY,
  email           CITEXT NOT NULL UNIQUE,
  phone           VARCHAR(32) NOT NULL,
  password_hash   TEXT NOT NULL,
  full_name       VARCHAR(200) NOT NULL,
  blood_group     VARCHAR(8) NOT NULL,
  address_line    TEXT,
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  location_updated_at TIMESTAMPTZ,
  share_location_for_matching BOOLEAN NOT NULL DEFAULT FALSE,
  credits         INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT blood_group_chk CHECK (
    blood_group IN ('A+','A-','B+','B-','O+','O-','AB+','AB-')
  )
);

CREATE INDEX IF NOT EXISTS idx_users_lat_lng
  ON users (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND share_location_for_matching;

CREATE TABLE IF NOT EXISTS blood_banks (
  id              BIGSERIAL PRIMARY KEY,
  name            VARCHAR(200) NOT NULL,
  email           CITEXT NOT NULL UNIQUE,
  phone           VARCHAR(32) NOT NULL,
  password_hash   TEXT NOT NULL,
  address_line    TEXT,
  latitude        DOUBLE PRECISION NOT NULL,
  longitude       DOUBLE PRECISION NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_blood_banks_lat_lng ON blood_banks (latitude, longitude);

CREATE TABLE IF NOT EXISTS blood_bank_inventory (
  blood_bank_id   BIGINT NOT NULL REFERENCES blood_banks (id) ON DELETE CASCADE,
  blood_group     VARCHAR(8) NOT NULL,
  units_available INT NOT NULL DEFAULT 0 CHECK (units_available >= 0),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (blood_bank_id, blood_group),
  CONSTRAINT blood_bank_inventory_group_chk CHECK (
    blood_group IN ('A+','A-','B+','B-','O+','O-','AB+','AB-')
  )
);

-- Haversine distance in meters (Earth radius 6371000 m). Clamps acos input for FP safety.
-- Used for consistent nearest-neighbor ordering for banks and donors.

CREATE TABLE IF NOT EXISTS appointments (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  blood_bank_id   BIGINT NOT NULL REFERENCES blood_banks (id) ON DELETE CASCADE,
  appointment_date TIMESTAMPTZ NOT NULL,
  status          VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT status_chk CHECK (
    status IN ('pending', 'completed', 'cancelled', 'no_show')
  )
);

CREATE TABLE IF NOT EXISTS blood_requests (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  blood_bank_id   BIGINT NOT NULL REFERENCES blood_banks (id) ON DELETE CASCADE,
  blood_group     VARCHAR(8) NOT NULL,
  units_needed    INT NOT NULL CHECK (units_needed > 0),
  patient_name    VARCHAR(200),
-- Blood Now — core schema (PostgreSQL)
-- Run: psql "%DATABASE_URL%" -f db/schema.sql   (Windows: set DATABASE_URL first)

CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE IF NOT EXISTS users (
  id              BIGSERIAL PRIMARY KEY,
  email           CITEXT NOT NULL UNIQUE,
  phone           VARCHAR(32) NOT NULL,
  password_hash   TEXT NOT NULL,
  full_name       VARCHAR(200) NOT NULL,
  blood_group     VARCHAR(8) NOT NULL,
  address_line    TEXT,
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  location_updated_at TIMESTAMPTZ,
  share_location_for_matching BOOLEAN NOT NULL DEFAULT FALSE,
  credits         INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT blood_group_chk CHECK (
    blood_group IN ('A+','A-','B+','B-','O+','O-','AB+','AB-')
  )
);

CREATE INDEX IF NOT EXISTS idx_users_lat_lng
  ON users (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND share_location_for_matching;

CREATE TABLE IF NOT EXISTS blood_banks (
  id              BIGSERIAL PRIMARY KEY,
  name            VARCHAR(200) NOT NULL,
  email           CITEXT NOT NULL UNIQUE,
  phone           VARCHAR(32) NOT NULL,
  password_hash   TEXT NOT NULL,
  address_line    TEXT,
  latitude        DOUBLE PRECISION NOT NULL,
  longitude       DOUBLE PRECISION NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_blood_banks_lat_lng ON blood_banks (latitude, longitude);

CREATE TABLE IF NOT EXISTS blood_bank_inventory (
  blood_bank_id   BIGINT NOT NULL REFERENCES blood_banks (id) ON DELETE CASCADE,
  blood_group     VARCHAR(8) NOT NULL,
  units_available INT NOT NULL DEFAULT 0 CHECK (units_available >= 0),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (blood_bank_id, blood_group),
  CONSTRAINT blood_bank_inventory_group_chk CHECK (
    blood_group IN ('A+','A-','B+','B-','O+','O-','AB+','AB-')
  )
);

-- Haversine distance in meters (Earth radius 6371000 m). Clamps acos input for FP safety.
-- Used for consistent nearest-neighbor ordering for banks and donors.

CREATE TABLE IF NOT EXISTS appointments (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  blood_bank_id   BIGINT NOT NULL REFERENCES blood_banks (id) ON DELETE CASCADE,
  appointment_date TIMESTAMPTZ NOT NULL,
  status          VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT status_chk CHECK (
    status IN ('pending', 'confirmed', 'donated', 'completed', 'cancelled', 'no_show')
  )
);

CREATE TABLE IF NOT EXISTS blood_requests (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  blood_bank_id   BIGINT NOT NULL REFERENCES blood_banks (id) ON DELETE CASCADE,
  blood_group     VARCHAR(8) NOT NULL,
  units_needed    INT NOT NULL CHECK (units_needed > 0),
  patient_name    VARCHAR(200),
  status          VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT req_status_chk CHECK (
    status IN ('pending', 'fulfilled', 'cancelled')
  ),
  CONSTRAINT req_blood_group_chk CHECK (
    blood_group IN ('A+','A-','B+','B-','O+','O-','AB+','AB-')
  )
);

CREATE TABLE IF NOT EXISTS impact_events (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  blood_bank_id   BIGINT NOT NULL REFERENCES blood_banks (id) ON DELETE CASCADE,
  donation_id     BIGINT NOT NULL REFERENCES appointments (id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
