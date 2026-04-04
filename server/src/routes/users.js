import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { body, validationResult } from 'express-validator';
import { pool } from '../db/pool.js';
import { requireUser } from '../middleware/auth.js';

const router = Router();

function mapUserRow(r) {
  return {
    id: r.id,
    email: r.email,
    fullName: r.full_name,
    phone: r.phone,
    bloodGroup: r.blood_group,
    credits: r.credits,
    addressLine: r.address_line,
    latitude: r.latitude,
    longitude: r.longitude,
    shareLocationForMatching: r.share_location_for_matching,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

router.get('/me', requireUser, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, email, full_name, phone, blood_group, credits, address_line, latitude, longitude,
              share_location_for_matching, created_at, updated_at
       FROM users WHERE id = $1`,
      [req.auth.sub],
    );
    const row = rows[0];
    if (!row) return res.status(404).json({ error: 'User not found' });
    return res.json({ user: mapUserRow(row) });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to load profile' });
  }
});

router.patch(
  '/me',
  requireUser,
  [
    body('fullName').optional().trim().isLength({ min: 2, max: 200 }),
    body('phone').optional().trim().isLength({ min: 8, max: 32 }),
    body('addressLine').optional({ nullable: true }).trim().isLength({ max: 2000 }),
    body('latitude').optional({ nullable: true }).isFloat({ min: -90, max: 90 }),
    body('longitude').optional({ nullable: true }).isFloat({ min: -180, max: 180 }),
    body('shareLocationForMatching')
      .optional()
      .isBoolean()
      .toBoolean(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { rows: currentRows } = await pool.query(
        `SELECT full_name, phone, blood_group, credits, address_line, latitude, longitude,
                share_location_for_matching
         FROM users WHERE id = $1`,
        [req.auth.sub],
      );
      const cur = currentRows[0];
      if (!cur) return res.status(404).json({ error: 'User not found' });

      const {
        fullName,
        phone,
        addressLine,
        latitude,
        longitude,
        shareLocationForMatching,
      } = req.body;

      let nextName = cur.full_name;
      let nextPhone = cur.phone;
      let nextAddr = cur.address_line;
      let nextLat = cur.latitude;
      let nextLng = cur.longitude;
      let nextShare = cur.share_location_for_matching;

      if (fullName !== undefined) nextName = fullName;
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
          nextLat = null;
          nextLng = null;
        } else {
          nextLat = latitude;
          nextLng = longitude;
        }
      }

      if (shareLocationForMatching !== undefined) {
        nextShare = shareLocationForMatching === true;
      }

      const hasCoords = nextLat != null && nextLng != null;
      if (nextShare && !hasCoords) {
        return res.status(400).json({
          error: 'Sharing location requires saved GPS coordinates',
        });
      }
      const shareStored = hasCoords && nextShare;

      const { rows } = await pool.query(
        `UPDATE users SET
          full_name = $2,
          phone = $3,
          address_line = $4,
          latitude = $5,
          longitude = $6,
          location_updated_at = $7,
          share_location_for_matching = $8,
          updated_at = NOW()
        WHERE id = $1
        RETURNING id, email, full_name, phone, blood_group, credits, address_line, latitude, longitude,
                  share_location_for_matching, created_at, updated_at`,
        [
          req.auth.sub,
          nextName,
          nextPhone,
          nextAddr,
          hasCoords ? nextLat : null,
          hasCoords ? nextLng : null,
          hasCoords ? new Date() : null,
          shareStored,
        ],
      );

      return res.json({ user: mapUserRow(rows[0]) });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'Update failed' });
    }
  },
);

/** Password change: practical addition for step 3 */
router.post(
  '/me/password',
  requireUser,
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
        'SELECT password_hash FROM users WHERE id = $1',
        [req.auth.sub],
      );
      const row = rows[0];
      if (!row) return res.status(404).json({ error: 'User not found' });
      const ok = await bcrypt.compare(currentPassword, row.password_hash);
      if (!ok) return res.status(401).json({ error: 'Current password is incorrect' });
      const hash = await bcrypt.hash(newPassword, 12);
      await pool.query(
        'UPDATE users SET password_hash = $2, updated_at = NOW() WHERE id = $1',
        [req.auth.sub, hash],
      );
      return res.json({ ok: true });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'Password change failed' });
    }
  },
);

router.get('/me/activity', requireUser, async (req, res) => {
  try {
    const { rows: appts } = await pool.query(
      `SELECT a.*, b.name as bank_name, b.latitude as bank_lat, b.longitude as bank_lng 
       FROM appointments a JOIN blood_banks b ON a.blood_bank_id = b.id 
       WHERE a.user_id = $1 ORDER BY a.appointment_date DESC`,
      [req.auth.sub]
    );
    const { rows: reqs } = await pool.query(
      `SELECT r.*, b.name as bank_name 
       FROM blood_requests r JOIN blood_banks b ON r.blood_bank_id = b.id 
       WHERE r.user_id = $1 ORDER BY r.created_at DESC`,
      [req.auth.sub]
    );
    return res.json({ appointments: appts, requests: reqs });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to fetch activity' });
  }
});

router.get('/me/donor-profile', requireUser, async (req, res) => {
  try {
    const { rows: uRows } = await pool.query('SELECT credits FROM users WHERE id = $1', [req.auth.sub]);
    if (uRows.length === 0) return res.status(404).json({ error: 'User not found' });
    const credits = uRows[0].credits;

    const { rows: appts } = await pool.query(
      `SELECT a.appointment_date, b.name as bank_name, b.latitude as bank_lat, b.longitude as bank_lng, u.blood_group, a.status 
       FROM appointments a
       JOIN blood_banks b ON a.blood_bank_id = b.id
       JOIN users u ON a.user_id = u.id
       WHERE a.user_id = $1
       ORDER BY a.appointment_date DESC`,
      [req.auth.sub]
    );

    const donatedAppts = appts.filter(a => a.status === 'donated');
    const totalDonations = donatedAppts.length;
    const lastDonationDate = totalDonations > 0 ? donatedAppts[0].appointment_date : null;
    const donationHistory = appts.map(a => ({
      date: a.appointment_date,
      bloodBankName: a.bank_name,
      bankLat: a.bank_lat,
      bankLng: a.bank_lng,
      units: 1, // exactly 1 unit per completed appointment
      bloodGroup: a.blood_group,
      status: a.status
    }));

    return res.json({
      credits,
      totalDonations,
      lastDonationDate,
      donationHistory
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to load donor profile' });
  }
});

router.get('/me/impact', requireUser, async (req, res) => {
  try {
    const { rows: events } = await pool.query(
      `SELECT ie.created_at as notification_date, a.appointment_date, b.name as bank_name, u.blood_group 
       FROM impact_events ie
       JOIN appointments a ON ie.donation_id = a.id
       JOIN blood_banks b ON ie.blood_bank_id = b.id
       JOIN users u ON ie.user_id = u.id
       WHERE ie.user_id = $1
       ORDER BY ie.created_at DESC`,
      [req.auth.sub]
    );

    const notifications = events.map(e => ({
      message: "Your " + e.blood_group + " donation on " + new Date(e.appointment_date).toLocaleDateString() + " helped someone today ❤️",
      date: e.notification_date,
      bankName: e.bank_name
    }));

    return res.json({
      impactScore: events.length,
      notifications
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to fetch impact details' });
  }
});

router.put('/me/fcm-token', requireUser, [
  body('fcmToken').notEmpty().isString()
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  
  try {
    await pool.query('UPDATE users SET fcm_token = $1, updated_at = NOW() WHERE id = $2', [req.body.fcmToken, req.auth.sub]);
    return res.json({ ok: true });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to save FCM token' });
  }
});

export default router;
