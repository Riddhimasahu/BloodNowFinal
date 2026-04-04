import os from 'os';
import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import { pool } from '../db/pool.js';
import { requireUser } from '../middleware/auth.js';
import { sendSosEmail, sendGenericEmail } from '../utils/mailer.js';

const router = Router();

// POST /api/sos-request
router.post(
  '/',
  requireUser,
  [
    body('bloodGroup').isIn(['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']),
    body('location.lat').isFloat({ min: -90, max: 90 }),
    body('location.lng').isFloat({ min: -180, max: 180 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { bloodGroup, location } = req.body;
    const requesterId = req.auth.sub; // From requireUser middleware

    try {
      // 1. Save SOS request
      const { rows: reqRows } = await pool.query(
        `INSERT INTO sos_requests (requester_id, blood_group, latitude, longitude, status)
         VALUES ($1, $2, $3, $4, 'pending') RETURNING id`,
        [requesterId, bloodGroup, parseFloat(location.lat), parseFloat(location.lng)]
      );
      const sosId = reqRows[0].id;

      // 2. Find eligible donors within 5km matching blood group
      // Haversine distance in meters: 5000 meters = 5km
      const { rows: donors } = await pool.query(
        `SELECT id, fcm_token, email, distance 
         FROM (
           SELECT id, fcm_token, email,
             (6371000 * acos(
               CASE WHEN cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2)) + 
               sin(radians($1)) * sin(radians(latitude)) > 1 THEN 1 
               ELSE cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2)) + 
               sin(radians($1)) * sin(radians(latitude)) END
             )) AS distance 
           FROM users 
           WHERE blood_group = $3 
             AND id != $4 
             AND latitude IS NOT NULL 
             AND longitude IS NOT NULL
         ) sub
         WHERE distance <= 5000`,
        [parseFloat(location.lat), parseFloat(location.lng), bloodGroup, requesterId]
      );

      if (donors.length > 0) {
        const title = `URGENT: Blood Needed Near You — ${bloodGroup}`;
        // Helper function to get the local IP address so mobile phones can connect
        function getLocalIp() {
          const interfaces = os.networkInterfaces();
          let backupIp = null;
          for (const name of Object.keys(interfaces)) {
            if (name.toLowerCase().includes('vethernet') || name.toLowerCase().includes('wsl') || name.toLowerCase().includes('virtual')) continue;
            for (const iface of interfaces[name]) {
              if (iface.family === 'IPv4' && !iface.internal) {
                if (iface.address.startsWith('192.168.') || iface.address.startsWith('10.')) return iface.address;
                if (!backupIp) backupIp = iface.address;
              }
            }
          }
          return backupIp || '127.0.0.1';
        }

        // Assuming the app is running locally for hackathon, but usually from env.
        const host = req.get('host');
        let baseUrl = process.env.APP_URL;
        if (!baseUrl) {
          if (host.includes('localhost') || host.includes('127.0.0.1')) {
            const port = host.split(':')[1] || '';
            const ip = getLocalIp();
            baseUrl = `${req.protocol}://${ip}${port ? ':' + port : ''}`;
          } else {
            baseUrl = `${req.protocol}://${host}`;
          }
        }

        // Send individual Email
        for (const d of donors) {
          if (!d.email) continue;
          
          const acceptLink = `${baseUrl}/api/sos-request/${sosId}/response?donorId=${d.id}&action=accept`;
          const declineLink = `${baseUrl}/api/sos-request/${sosId}/response?donorId=${d.id}&action=decline`;

          const bodyMsg = `
            <div style="font-family: Arial, sans-serif; background-color: #fce4e4; padding: 20px; border-radius: 10px; max-width: 600px; margin: 0 auto; color: #333;">
              <h2 style="color: #c62828; text-align: center;">Emergency Blood Request 🩸</h2>
              <p>There is an emergency nearby, someone needs <b>${bloodGroup}</b> blood in your approximate area!</p>
              <p>You are receiving this because you are within a 5km radius of the requester.</p>
              <br/>
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="margin: 0 auto; width: 100%;">
                <tr>
                  <td align="center" style="padding: 10px;">
                    <a href="${acceptLink}" style="display: inline-block; padding: 12px 24px; background-color: #2e7d32; color: #ffffff; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px; min-width: 200px;">I Can Help (Accept)</a>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding: 10px;">
                    <a href="${declineLink}" style="display: inline-block; padding: 12px 24px; background-color: #757575; color: #ffffff; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px; min-width: 200px;">Sorry, I Cannot</a>
                  </td>
                </tr>
              </table>
              <p style="font-size: 14px; text-align: center; color: #777; margin-top: 20px;">- The BloodNow Team</p>
            </div>
          `;

          sendSosEmail(d.email, title, bodyMsg);
        }
      }

      return res.status(201).json({
        message: 'SOS request sent',
        donorsNotifiedCount: donors.length
      });
    } catch (e) {
      console.error('SOS request failed:', e);
      return res.status(500).json({ error: 'Failed to process SOS request' });
    }
  }
);

// GET /api/sos/:sosId/response
router.get('/:sosId/response', async (req, res) => {
  const { sosId } = req.params;
  const { donorId, action } = req.query;

  if (!sosId || !donorId || !action) {
    return res.status(400).send('Invalid request parameters.');
  }

  try {
    const { rows: sosRows } = await pool.query('SELECT * FROM sos_requests WHERE id = $1', [sosId]);
    if (sosRows.length === 0) return res.status(404).send('SOS request not found.');
    const sosReq = sosRows[0];

    if (action === 'decline') {
      // Could log decline in DB. Here we just show a thank you page.
      return res.send('<h3 style="color: grey; font-family: sans-serif; text-align:center; padding: 40px;">Thank you for letting us know. We will continue searching for other donors.</h3>');
    }

    if (action === 'accept') {
      if (sosReq.status === 'fulfilled') {
        return res.send('<h3 style="color: #2e7d32; font-family: sans-serif; text-align:center; padding: 40px;">Thank you for your willingness to help! Another donor has already accepted this request.</h3>');
      }

      // Mark SOS fulfilled
      await pool.query("UPDATE sos_requests SET status = 'fulfilled' WHERE id = $1", [sosId]);

      // Fetch donor info
      const { rows: dRows } = await pool.query('SELECT full_name, phone, email, blood_group FROM users WHERE id = $1', [donorId]);
      const donorInfo = dRows[0];

      // Fetch requester email
      const { rows: rRows } = await pool.query('SELECT email, full_name, latitude, longitude FROM users WHERE id = $1', [sosReq.requester_id]);
      const reqInfo = rRows[0];

      if (reqInfo && reqInfo.email) {
        // Send email to requester with donor details
        const rSubject = "Good News — A Donor Has Accepted Your Request";
        const rHtml = `
          <div style="font-family: Arial, sans-serif; padding: 20px; background-color:#e8f5e9; border-radius: 10px;">
            <p>Hello ${reqInfo.full_name},</p>
            <p>stay calm donor mil gya he.</p>
            <ul>
              <li>Donor Name: ${donorInfo.full_name}</li>
              <li>Phone Number: ${donorInfo.phone}</li>
              <li>Email: ${donorInfo.email}</li>
              <li>Blood Group: ${donorInfo.blood_group}</li>
            </ul>
          </div>
        `;
        sendGenericEmail(reqInfo.email, rSubject, rHtml);
      }

      // Email all other donors that would have been notified
      const { rows: otherDonors } = await pool.query(
        `SELECT id, email,
           (6371000 * acos(
             CASE WHEN cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2)) + 
             sin(radians($1)) * sin(radians(latitude)) > 1 THEN 1 
             ELSE cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2)) + 
             sin(radians($1)) * sin(radians(latitude)) END
           )) AS distance 
         FROM users 
         WHERE blood_group = $3 AND id != $4 AND id != $5 AND latitude IS NOT NULL AND longitude IS NOT NULL`,
        [parseFloat(sosReq.latitude), parseFloat(sosReq.longitude), sosReq.blood_group, sosReq.requester_id, donorId]
      );

      const otherEmails = otherDonors.filter(d => d.distance <= 5000 && d.email).map(d => d.email);
      for (const oe of otherEmails) {
        sendGenericEmail(oe, "Emergency Request Update", "<div style='font-family: Arial, sans-serif; padding: 20px;'><p>donor mil gya he ab koi need nhi he kisi or donor ki.</p></div>");
      }

      return res.send(`
        <div style="font-family: sans-serif; text-align:center; padding: 40px; background-color:#e8f5e9;">
          <h2 style="color: #2e7d32;">You are a Hero! ❤️</h2>
          <p>Thank you for accepting to donate! The requester has been notified and provided with your contact details.</p>
        </div>
      `);
    }

    return res.status(400).send('Invalid action.');
  } catch (err) {
    console.error('Action failed:', err);
    return res.status(500).send('Server Error while processing action.');
  }
});

export default router;
