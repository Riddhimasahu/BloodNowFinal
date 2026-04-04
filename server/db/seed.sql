-- Sample blood banks + inventory for local testing (Bangalore-ish coordinates)
-- Password for bank login is NOT set here — use registration API or update hash manually.
-- These rows assume schema is empty; truncate if re-seeding.

INSERT INTO blood_banks (name, email, phone, password_hash, address_line, latitude, longitude)
VALUES
  (
    'City Central Blood Bank',
    'citycentral@example.test',
    '+911111000001',
    '$2b$10$Lbu5diYkyJeNtLp/xsaqJuoDE5QcBsfO2/z9n/Trj7AE7RCGMWpwy',
    'MG Road',
    12.9716,
    77.5946
  ),
  (
    'Eastside Plasma & Blood Center',
    'eastside@example.test',
    '+911111000002',
    '$2b$10$Lbu5diYkyJeNtLp/xsaqJuoDE5QcBsfO2/z9n/Trj7AE7RCGMWpwy',
    'Whitefield',
    12.9698,
    77.7500
  ),
  (
    'South Care Blood Bank',
    'southcare@example.test',
    '+911111000003',
    '$2b$10$Lbu5diYkyJeNtLp/xsaqJuoDE5QcBsfO2/z9n/Trj7AE7RCGMWpwy',
    'Jayanagar',
    12.9250,
    77.5938
  )
ON CONFLICT (email) DO NOTHING;

INSERT INTO blood_bank_inventory (blood_bank_id, blood_group, units_available)
SELECT id, g, u
FROM blood_banks bb
CROSS JOIN (VALUES
  ('A+', 5),
  ('B+', 3),
  ('O+', 8),
  ('AB+', 1)
) AS v(g, u)
WHERE bb.email = 'citycentral@example.test'
ON CONFLICT (blood_bank_id, blood_group) DO NOTHING;

INSERT INTO blood_bank_inventory (blood_bank_id, blood_group, units_available)
SELECT id, g, u
FROM blood_banks bb
CROSS JOIN (VALUES
  ('A+', 2),
  ('O+', 4)
) AS v(g, u)
WHERE bb.email = 'eastside@example.test'
ON CONFLICT (blood_bank_id, blood_group) DO NOTHING;

INSERT INTO blood_bank_inventory (blood_bank_id, blood_group, units_available)
SELECT id, g, u
FROM blood_banks bb
CROSS JOIN (VALUES
  ('B+', 6),
  ('O-', 2)
) AS v(g, u)
WHERE bb.email = 'southcare@example.test'
ON CONFLICT (blood_bank_id, blood_group) DO NOTHING;
