import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { body, validationResult } from 'express-validator';
import { BLOOD_GROUPS } from '../constants/bloodGroups.js';
import { OAuth2Client } from 'google-auth-library';
import { pool } from '../db/pool.js';
import { signToken } from '../utils/jwt.js';

const googleClient = new OAuth2Client();

const router = Router();

router.post(
  '/register',
  [
    body('email').isEmail().normalizeEmail(),
    body('phone').trim().isLength({ min: 8, max: 32 }),
    body('password').isLength({ min: 8 }),
    body('fullName').trim().isLength({ min: 2, max: 200 }),
    body('bloodGroup').isIn(BLOOD_GROUPS),
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

    const {
      email,
      phone,
      password,
      fullName,
      bloodGroup,
      addressLine,
      latitude,
      longitude,
      shareLocationForMatching,
    } = req.body;

    const latSet = latitude !== undefined && latitude !== null;
    const lngSet = longitude !== undefined && longitude !== null;
    if (latSet !== lngSet) {
      return res.status(400).json({
        error: 'Provide both latitude and longitude, or omit both',
      });
    }
    const hasCoords = latSet && lngSet;

    if (shareLocationForMatching === true && !hasCoords) {
      return res.status(400).json({
        error: 'Sharing location for matching requires GPS coordinates',
      });
    }

    const share = shareLocationForMatching === true && hasCoords;

    const passwordHash = await bcrypt.hash(password, 12);

    try {
      const { rows } = await pool.query(
        `INSERT INTO users (
          email, phone, password_hash, full_name, blood_group, address_line,
          latitude, longitude, location_updated_at, share_location_for_matching
        ) VALUES (
          $1, $2, $3, $4, $5, $6,
          $7, $8,
          $9,
          $10
        )
        RETURNING id, email, phone, full_name, blood_group, address_line, latitude, longitude,
                  share_location_for_matching, created_at, role, blood_bank_id`,
        [
          email,
          phone,
          passwordHash,
          fullName,
          bloodGroup,
          addressLine ?? null,
          hasCoords ? latitude : null,
          hasCoords ? longitude : null,
          hasCoords ? new Date() : null,
          share,
        ],
      );

      const user = rows[0];
      const token = signToken({
        sub: String(user.id),
        email: user.email,
        typ: 'user',
        role: user.role,
        blood_bank_id: user.blood_bank_id,
      });

      return res.status(201).json({
        token,
        user: {
          id: user.id,
          email: user.email,
          phone: user.phone,
          fullName: user.full_name,
          bloodGroup: user.blood_group,
          addressLine: user.address_line,
          latitude: user.latitude,
          longitude: user.longitude,
          shareLocationForMatching: user.share_location_for_matching,
          role: user.role,
          blood_bank_id: user.blood_bank_id,
        },
      });
    } catch (e) {
      if (e.code === '23505') {
        if (e.constraint === 'users_phone_key') {
          return res.status(409).json({ error: 'Phone number already registered' });
        }
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
        `SELECT id, email, phone, password_hash, full_name, blood_group, address_line,
                latitude, longitude, share_location_for_matching, role, blood_bank_id
         FROM users WHERE email = $1`,
        [email],
      );
      const user = rows[0];
      if (!user || !(await bcrypt.compare(password, user.password_hash))) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const token = signToken({
        sub: String(user.id),
        email: user.email,
        typ: 'user',
        role: user.role,
        blood_bank_id: user.blood_bank_id,
      });

      return res.json({
        token,
        user: {
          id: user.id,
          email: user.email,
          phone: user.phone,
          fullName: user.full_name,
          bloodGroup: user.blood_group,
          addressLine: user.address_line,
          latitude: user.latitude,
          longitude: user.longitude,
          shareLocationForMatching: user.share_location_for_matching,
          role: user.role,
          blood_bank_id: user.blood_bank_id,
        },
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'Login failed' });
    }
  },
);

router.post(
  '/google',
  [
    body('idToken').notEmpty(),
    body('password').optional().isLength({ min: 8 }),
    body('phone').optional().trim().isLength({ min: 8, max: 32 }),
    body('bloodGroup').optional().isIn(BLOOD_GROUPS),
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

    const {
      idToken,
      password,
      phone,
      bloodGroup,
      addressLine,
      latitude,
      longitude,
      shareLocationForMatching,
    } = req.body;

    try {
      const ticket = await googleClient.verifyIdToken({
        idToken,
      });
      const payload = ticket.getPayload();
      if (!payload || !payload.email) {
        return res.status(400).json({ error: 'Invalid Google token' });
      }

      const { email, name: fullName, picture } = payload;

      const { rows } = await pool.query(
        `SELECT id, email, phone, password_hash, full_name, blood_group, address_line,
                latitude, longitude, share_location_for_matching, role, blood_bank_id
         FROM users WHERE email = $1`,
        [email],
      );
      let user = rows[0];

      if (!user) {
        // If they provided the required missing fields for registration
        if (phone && bloodGroup) {
          const latSet = latitude !== undefined && latitude !== null;
          const lngSet = longitude !== undefined && longitude !== null;
          if (latSet !== lngSet) {
            return res.status(400).json({
              error: 'Provide both latitude and longitude, or omit both',
            });
          }
          const hasCoords = latSet && lngSet;
          const share = shareLocationForMatching === true && hasCoords;

          // use provided password or generate a random impossible password hash for Google-only users
          const dummyPasswordHash = password 
            ? await bcrypt.hash(password, 12) 
            : await bcrypt.hash(Math.random().toString(36), 12);

          const { rows: newRows } = await pool.query(
            `INSERT INTO users (
              email, phone, password_hash, full_name, blood_group, address_line,
              latitude, longitude, location_updated_at, share_location_for_matching
            ) VALUES (
              $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
            ) RETURNING id, email, phone, full_name, blood_group, address_line, latitude, longitude, share_location_for_matching, created_at, role, blood_bank_id`,
            [
              email,
              phone,
              dummyPasswordHash,
              fullName,
              bloodGroup,
              addressLine ?? null,
              hasCoords ? latitude : null,
              hasCoords ? longitude : null,
              hasCoords ? new Date() : null,
              share,
            ],
          );
          user = newRows[0];
        } else {
          // Tell frontend to collect the missing info
          return res.status(200).json({
            isNewUser: true,
            email,
            fullName,
            picture,
          });
        }
      }

      // Login success
      const token = signToken({
        sub: String(user.id),
        email: user.email,
        typ: 'user',
        role: user.role,
        blood_bank_id: user.blood_bank_id,
      });

      return res.json({
        token,
        user: {
          id: user.id,
          email: user.email,
          phone: user.phone,
          fullName: user.full_name,
          bloodGroup: user.blood_group,
          addressLine: user.address_line,
          latitude: user.latitude,
          longitude: user.longitude,
          shareLocationForMatching: user.share_location_for_matching,
          role: user.role,
          blood_bank_id: user.blood_bank_id,
        },
      });
    } catch (e) {
      if (e.code === '23505') {
        if (e.constraint === 'users_phone_key') {
          return res.status(409).json({ error: 'Phone number already registered' });
        }
        return res.status(409).json({ error: 'Email already registered' });
      }
      console.error(e);
      return res.status(401).json({ error: 'Google authentication failed' });
    }
  },
);

export default router;
