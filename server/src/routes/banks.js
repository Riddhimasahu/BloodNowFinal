import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { body, validationResult } from 'express-validator';
import { BLOOD_GROUPS } from '../constants/bloodGroups.js';
import { pool } from '../db/pool.js';
import { requireBank, requireUser } from '../middleware/auth.js';
import { signToken } from '../utils/jwt.js';
import { sendImpactEmail, sendGenericEmail } from '../utils/mailer.js';

const router = Router();

function mapBankRow(r) {
  return {
    id: r.id,
    name: r.name,
    email: r.email,
    phone: r.phone,
    addressLine: r.address_line,
    latitude: r.latitude,
    longitude: r.longitude,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

router.post(
  '/register',
  [
    body('name').trim().isLength({ min: 2, max: 200 }),
    body('email').isEmail().normalizeEmail(),
    body('phone').trim().isLength({ min: 8, max: 32 }),
    body('password').isLength({ min: 8 }),
    body('addressLine').optional({ nullable: true }).trim().isLength({ max: 2000 }),
    body('latitude').isFloat({ min: -90, max: 90 }),
    body('longitude').isFloat({ min: -180, max: 180 }),
  ],
  async (req, res) => {
    return res.status(403).json({ error: 'Registration disabled. Using predefined Kota entries.' });
    
    // Original validation:
    // const errors = validationResult(req);
    // if (!errors.isEmpty()) {
    //   return res.status(400).json({ errors: errors.array() });
    // }
    //
    // const { name, email, phone, password, addressLine, latitude, longitude } = req.body;
    // const passwordHash = await bcrypt.hash(password, 12);

    try {
      const { rows } = await pool.query(
        `INSERT INTO blood_banks (name, email, phone, password_hash, address_line, latitude, longitude)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id, name, email, phone, address_line, latitude, longitude, created_at, updated_at`,
        [name, email, phone, passwordHash, addressLine ?? null, latitude, longitude],
      );

      const bank = rows[0];
      const token = signToken({
        sub: String(bank.id),
        email: bank.email,
        typ: 'bank',
      });

      return res.status(201).json({
        token,
        bank: mapBankRow(bank),
      });
    } catch (e) {
      if (e.code === '23505') {
        return res.status(409).json({ error: 'Email already registered' });
      }
      console.error(e);
      return res.status(500).json({ error: 'Registration failed' });
    }
  },
);

router.post(
  '/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password } = req.body;

    try {
      const { rows } = await pool.query(
        `SELECT id, name, email, phone, password_hash, address_line, latitude, longitude, created_at, updated_at
         FROM blood_banks WHERE email = $1`,
        [email],
      );
      const bank = rows[0];
      if (!bank || !(await bcrypt.compare(password, bank.password_hash))) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const token = signToken({
        sub: String(bank.id),
        email: bank.email,
        typ: 'bank',
      });

      return res.json({
        token,
        bank: mapBankRow(bank),
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'Login failed' });
    }
  },
);

router.get('/me/inventory', requireBank, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT blood_group, units_available, updated_at
       FROM blood_bank_inventory WHERE blood_bank_id = $1`,
      [req.auth.sub],
    );
    const byGroup = new Map(rows.map((r) => [r.blood_group, r]));
    const items = BLOOD_GROUPS.map((g) => {
      const r = byGroup.get(g);
      return {
        bloodGroup: g,
        unitsAvailable: r ? r.units_available : 0,
        updatedAt: r?.updated_at ?? null,
      };
    });
    return res.json({ items });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to load inventory' });
  }
});

router.put(
  '/me/inventory',
  requireBank,
  [body('units').isObject()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const units = req.body.units;
    const keys = Object.keys(units);
    for (const k of keys) {
      if (!BLOOD_GROUPS.includes(k)) {
        return res.status(400).json({ error: `Invalid blood group key: ${k}` });
      }
      const v = units[k];
      if (!Number.isInteger(v) || v < 0 || v > 999) {
        return res.status(400).json({
          error: `Invalid units for ${k} (integer 0–999)`,
        });
      }
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      for (const g of BLOOD_GROUPS) {
        if (!Object.prototype.hasOwnProperty.call(units, g)) continue;
        const n = units[g];
        await client.query(
          `INSERT INTO blood_bank_inventory (blood_bank_id, blood_group, units_available, updated_at)
           VALUES ($1, $2, $3, NOW())
           ON CONFLICT (blood_bank_id, blood_group)
           DO UPDATE SET units_available = EXCLUDED.units_available, updated_at = NOW()`,
          [req.auth.sub, g, n],
        );
      }
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      console.error(e);
      return res.status(500).json({ error: 'Inventory update failed' });
    } finally {
      client.release();
    }

    const { rows } = await pool.query(
      `SELECT blood_group, units_available, updated_at
       FROM blood_bank_inventory WHERE blood_bank_id = $1`,
      [req.auth.sub],
    );
    const byGroup = new Map(rows.map((r) => [r.blood_group, r]));
    const items = BLOOD_GROUPS.map((g) => {
      const r = byGroup.get(g);
      return {
        bloodGroup: g,
        unitsAvailable: r ? r.units_available : 0,
        updatedAt: r?.updated_at ?? null,
      };
    });
    return res.json({ items });
  },
);

router.get('/me', requireBank, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, name, email, phone, address_line, latitude, longitude, created_at, updated_at
       FROM blood_banks WHERE id = $1`,
      [req.auth.sub],
    );
    const row = rows[0];
    if (!row) return res.status(404).json({ error: 'Blood bank not found' });
    return res.json({ bank: mapBankRow(row) });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to load profile' });
  }
});

router.patch(
  '/me',
  requireBank,
  [
    body('name').optional().trim().isLength({ min: 2, max: 200 }),
    body('phone').optional().trim().isLength({ min: 8, max: 32 }),
    body('addressLine').optional({ nullable: true }).trim().isLength({ max: 2000 }),
    body('latitude').optional({ nullable: true }).isFloat({ min: -90, max: 90 }),
    body('longitude').optional({ nullable: true }).isFloat({ min: -180, max: 180 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { rows: curRows } = await pool.query(
        `SELECT name, phone, address_line, latitude, longitude FROM blood_banks WHERE id = $1`,
        [req.auth.sub],
      );
      const cur = curRows[0];
      if (!cur) return res.status(404).json({ error: 'Blood bank not found' });

      const { name, phone, addressLine, latitude, longitude } = req.body;

      let nextName = cur.name;
      let nextPhone = cur.phone;
      let nextAddr = cur.address_line;
      let nextLat = cur.latitude;
      let nextLng = cur.longitude;

      if (name !== undefined) nextName = name;
      if (phone !== undefined) nextPhone = phone;
      if (addressLine !== undefined) nextAddr = addressLine ?? null;

      const latProvided = latitude !== undefined;
      const lngProvided = longitude !== undefined;
      if (latProvided !== lngProvided) {
        return res.status(400).json({
          error: 'Provide both latitude and longitude, or omit both',
        });
      }
      if (latProvided && lngProvided) {
        if (latitude == null || longitude == null) {
          return res.status(400).json({
            error: 'Blood bank location cannot be cleared; update to new coordinates',
          });
        }
        nextLat = latitude;
        nextLng = longitude;
      }

      const { rows } = await pool.query(
        `UPDATE blood_banks SET
          name = $2,
          phone = $3,
          address_line = $4,
          latitude = $5,
          longitude = $6,
          updated_at = NOW()
        WHERE id = $1
        RETURNING id, name, email, phone, address_line, latitude, longitude, created_at, updated_at`,
        [req.auth.sub, nextName, nextPhone, nextAddr, nextLat, nextLng],
      );

      return res.json({ bank: mapBankRow(rows[0]) });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'Update failed' });
    }
  },
);

router.post(
  '/me/password',
  requireBank,
  [
    body('currentPassword').notEmpty(),
    body('newPassword').isLength({ min: 8 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    const { currentPassword, newPassword } = req.body;
    try {
      const { rows } = await pool.query(
        'SELECT password_hash FROM blood_banks WHERE id = $1',
        [req.auth.sub],
      );
      const row = rows[0];
      if (!row) return res.status(404).json({ error: 'Not found' });
      const ok = await bcrypt.compare(currentPassword, row.password_hash);
      if (!ok) return res.status(401).json({ error: 'Current password is incorrect' });
      const hash = await bcrypt.hash(newPassword, 12);
      await pool.query(
        'UPDATE blood_banks SET password_hash = $2, updated_at = NOW() WHERE id = $1',
        [req.auth.sub, hash],
      );
      return res.json({ ok: true });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'Password change failed' });
    }
  },
);

// --- Donor Endpoints ---
router.post('/:id/appointments', requireUser, async (req, res) => {
  const bankId = req.params.id;
  const { date } = req.body; 
  if (!date) return res.status(400).json({ error: 'Date is required' });

  try {
    const { rows } = await pool.query(
      `INSERT INTO appointments (user_id, blood_bank_id, appointment_date)
       VALUES ($1, $2, $3) RETURNING *`,
      [req.auth.sub, bankId, new Date(date)],
    );
    return res.status(201).json({ appointment: rows[0] });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to book appointment' });
  }
});

router.post('/:id/requests', requireUser, async (req, res) => {
  const bankId = req.params.id;
  const { bloodGroup, unitsNeeded, patientName, patientAge } = req.body;
  if (!bloodGroup || !unitsNeeded) return res.status(400).json({ error: 'Missing fields' });

  try {
    const { rows } = await pool.query(
      `INSERT INTO blood_requests (user_id, blood_bank_id, blood_group, units_needed, patient_name, patient_age)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [req.auth.sub, bankId, bloodGroup, unitsNeeded, patientName, patientAge ? parseInt(patientAge, 10) : null],
    );
    return res.status(201).json({ request: rows[0] });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to submit request' });
  }
});

// --- Bank Endpoints ---
router.get('/me/appointments', requireBank, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT a.*, u.full_name, u.blood_group,
              EXISTS(SELECT 1 FROM impact_events ie WHERE ie.donation_id = a.id) as is_used
       FROM appointments a
       JOIN users u ON a.user_id = u.id
       WHERE a.blood_bank_id = $1
       ORDER BY a.appointment_date DESC`,
      [req.auth.sub]
    );
    return res.json({ appointments: rows });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed' });
  }
});

router.patch('/me/appointments/:id', requireBank, async (req, res) => {
  const { status } = req.body;
  try {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query(
        `UPDATE appointments SET status = $1, updated_at = NOW() 
         WHERE id = $2 AND blood_bank_id = $3 RETURNING *`,
        [status, req.params.id, req.auth.sub]
      );
      const appt = rows[0];
      if (!appt) throw new Error('Not found');

      if (status === 'donated') {
        await client.query(`UPDATE users SET credits = credits + 1 WHERE id = $1`, [appt.user_id]);
        const { rows: uRows } = await client.query(`SELECT blood_group FROM users WHERE id = $1`, [appt.user_id]);
        if (uRows.length > 0) {
           await client.query(
             `INSERT INTO blood_bank_inventory (blood_bank_id, blood_group, units_available, updated_at)
              VALUES ($1, $2, 1, NOW())
              ON CONFLICT (blood_bank_id, blood_group) DO UPDATE SET units_available = blood_bank_inventory.units_available + 1, updated_at = NOW()`,
             [req.auth.sub, uRows[0].blood_group]
           );
        }
      }
      if (status === 'confirmed') {
         const { rows: uRows } = await client.query(`SELECT full_name, email FROM users WHERE id = $1`, [appt.user_id]);
         const { rows: bRows } = await client.query(`SELECT name, address_line FROM blood_banks WHERE id = $1`, [appt.blood_bank_id]);
         if (uRows.length > 0 && bRows.length > 0) {
           appt._donorName = uRows[0].full_name;
           appt._donorEmail = uRows[0].email;
           appt._bankName = bRows[0].name;
           appt._bankAddress = bRows[0].address_line;
         }
      }
      await client.query('COMMIT');
      
      if (status === 'confirmed' && appt._donorEmail) {
        const dateStr = new Date(appt.appointment_date).toLocaleString('en-IN', {
          timeZone: 'Asia/Kolkata',
          dateStyle: 'long',
          timeStyle: 'short',
        });
        const html = `
          <div style="font-family: Arial, sans-serif; background-color: #fce4e4; padding: 20px; border-radius: 10px; max-width: 600px; margin: 0 auto; color: #333;">
            <h2 style="color: #c62828; text-align: center;">Appointment Confirmed! 🏥</h2>
            <p style="font-size: 16px;">Hello ${appt._donorName},</p>
            <p style="font-size: 16px; line-height: 1.5;">
              Your blood donation appointment at <strong>${appt._bankName}</strong> has been confirmed.
            </p>
            <div style="background-color: #fff; padding: 15px; border-radius: 8px; margin: 15px 0; border-left: 4px solid #c62828;">
              <p style="margin: 5px 0; font-size: 15px;"><strong>📅 Timing:</strong> ${dateStr}</p>
              <p style="margin: 5px 0; font-size: 15px;"><strong>📍 Location:</strong> ${appt._bankAddress || 'Address not provided'}</p>
            </div>
            <p style="font-size: 16px; line-height: 1.5;">
              Thank you for stepping up to be a hero. We look forward to seeing you there!
            </p>
            <p style="font-size: 14px; text-align: center; color: #777; margin-top: 30px;">
              - The BloodNow Team
            </p>
          </div>
        `;
        sendGenericEmail(appt._donorEmail, 'Blood Donation Appointment Confirmed', html).catch(console.error);
      }
      
      return res.json({ appointment: appt });
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed' });
  }
});

router.get('/me/requests', requireBank, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT * FROM blood_requests WHERE blood_bank_id = $1 ORDER BY created_at DESC`,
      [req.auth.sub]
    );
    return res.json({ requests: rows });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed' });
  }
});

router.patch('/me/requests/:id', requireBank, async (req, res) => {
  const { status } = req.body;
  try {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query(
        `UPDATE blood_requests SET status = $1, updated_at = NOW() 
         WHERE id = $2 AND blood_bank_id = $3 RETURNING *`,
        [status, req.params.id, req.auth.sub]
      );
      const reqRow = rows[0];
      if (!reqRow) throw new Error('Not found');

      if (status === 'fulfilled') {
        await client.query(
          `UPDATE blood_bank_inventory SET units_available = GREATEST(units_available - $1, 0), updated_at = NOW()
           WHERE blood_bank_id = $2 AND blood_group = $3`,
          [reqRow.units_needed, req.auth.sub, reqRow.blood_group]
        );
      }
      await client.query('COMMIT');
      return res.json({ request: reqRow });
    } catch(e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed' });
  }
});

router.post('/mark-used', requireBank, async (req, res) => {
  const { donationId, bloodBankId } = req.body;
  if (!donationId) return res.status(400).json({ error: 'donationId is required' });

  const bankId = bloodBankId || req.auth.sub;
  if (String(bankId) !== String(req.auth.sub)) {
    return res.status(403).json({ error: 'Unauthorized bank' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows: appts } = await client.query(
      `SELECT a.*, u.email, u.blood_group 
       FROM appointments a 
       JOIN users u ON a.user_id = u.id 
       WHERE a.id = $1 AND a.blood_bank_id = $2`,
      [donationId, req.auth.sub]
    );
    const appt = appts[0];
    if (!appt) throw new Error('Appointment not found or unauthorized');
    if (appt.status !== 'donated') throw new Error('Donation must be marked as donated before being dispatched');

    const { rows: events } = await client.query(
      `INSERT INTO impact_events (user_id, blood_bank_id, donation_id)
       VALUES ($1, $2, $3)
       ON CONFLICT DO NOTHING
       RETURNING id`,
      [appt.user_id, appt.blood_bank_id, appt.id]
    );
    
    if (events.length === 0) {
      throw new Error('Donation already marked as used');
    }

    await client.query('COMMIT');
    
    await sendImpactEmail(appt.email, appt.blood_group, new Date(appt.appointment_date).toLocaleDateString());

    return res.json({ ok: true, message: 'Impact notification sent!' });
  } catch (e) {
    await client.query('ROLLBACK');
    console.error(e);
    return res.status(500).json({ error: e.message || 'Failed to mark as used' });
  } finally {
    client.release();
  }
});

export default router;
