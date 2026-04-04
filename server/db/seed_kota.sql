-- Verified Blood Banks in Kota, Rajasthan
-- Clear existing to prevent fake entries
TRUNCATE TABLE blood_bank_inventory CASCADE;
TRUNCATE TABLE blood_banks CASCADE;

-- Insert verified Kota Blood Banks
-- IMPORTANT: The default password for all seeded blood banks is "kotaBank2024"
INSERT INTO blood_banks (name, email, phone, password_hash, address_line, latitude, longitude)
VALUES
  (
    'MBS Hospital Blood Bank',
    'mbsbank@kota.test',
    '+910000000001',
    '$2b$10$iHSxqD/kJdIxFz/pnxWCVOmqoD6m/yoXmpClu5YPfKwx0ByZMMBn2',
    'Nayapura, Kota, Rajasthan',
    25.1843,
    75.8344
  ),
  (
    'Jay Kay Lon Hospital',
    'jklon@kota.test',
    '+910000000002',
    '$2b$10$iHSxqD/kJdIxFz/pnxWCVOmqoD6m/yoXmpClu5YPfKwx0ByZMMBn2',
    'Nayapura, Kota, Rajasthan',
    25.1882,
    75.8288
  ),
  (
    'Sudha Hospital Blood Bank',
    'sudha@kota.test',
    '+910000000003',
    '$2b$10$iHSxqD/kJdIxFz/pnxWCVOmqoD6m/yoXmpClu5YPfKwx0ByZMMBn2',
    'Talwandi, Kota, Rajasthan',
    25.1432,
    75.8354
  ),
  (
    'TT Hospital Medical Center',
    'tthospital@kota.test',
    '+910000000004',
    '$2b$10$iHSxqD/kJdIxFz/pnxWCVOmqoD6m/yoXmpClu5YPfKwx0ByZMMBn2',
    'Vigyan Nagar, Kota, Rajasthan',
    25.1384,
    75.8450
  )
ON CONFLICT (email) DO NOTHING;

-- Also unify them in the users table so they can log in seamlessly
INSERT INTO users (email, phone, password_hash, full_name, blood_group, address_line, latitude, longitude, role, blood_bank_id)
SELECT email, phone, password_hash, name, 'O+', address_line, latitude, longitude, 'blood_bank', id
FROM blood_banks
ON CONFLICT (email) DO UPDATE SET role = 'blood_bank', blood_bank_id = EXCLUDED.blood_bank_id;

-- Optionally, seed some inventory so they show up for searches
INSERT INTO blood_bank_inventory (blood_bank_id, blood_group, units_available)
SELECT id, g, u
FROM blood_banks bb
CROSS JOIN (VALUES
  ('A+', 15), ('B+', 20), ('O+', 10), ('AB+', 5),
  ('A-', 2), ('B-', 3), ('O-', 4), ('AB-', 1)
) AS v(g, u)
WHERE bb.email = 'mbsbank@kota.test'
ON CONFLICT (blood_bank_id, blood_group) DO NOTHING;

INSERT INTO blood_bank_inventory (blood_bank_id, blood_group, units_available)
SELECT id, g, u
FROM blood_banks bb
CROSS JOIN (VALUES
  ('A+', 8), ('B+', 12), ('O+', 5), ('AB+', 2)
) AS v(g, u)
WHERE bb.email = 'jklon@kota.test'
ON CONFLICT (blood_bank_id, blood_group) DO NOTHING;

INSERT INTO blood_bank_inventory (blood_bank_id, blood_group, units_available)
SELECT id, g, u
FROM blood_banks bb
CROSS JOIN (VALUES
  ('A+', 5), ('B+', 5), ('O+', 5), ('AB+', 0)
) AS v(g, u)
WHERE bb.email = 'sudha@kota.test'
ON CONFLICT (blood_bank_id, blood_group) DO NOTHING;

INSERT INTO blood_bank_inventory (blood_bank_id, blood_group, units_available)
SELECT id, g, u
FROM blood_banks bb
CROSS JOIN (VALUES
  ('A+', 10), ('B+', 10), ('O-', 5)
) AS v(g, u)
WHERE bb.email = 'tthospital@kota.test'
ON CONFLICT (blood_bank_id, blood_group) DO NOTHING;
