import { Router } from 'express';
import { query, validationResult } from 'express-validator';
import { BLOOD_GROUPS } from '../constants/bloodGroups.js';
import { pool } from '../db/pool.js';
import { requireUser } from '../middleware/auth.js';
import { maskPhone } from '../utils/phoneMask.js';

const router = Router();

/**
 * Nearest-neighbor ordering uses the Haversine great-circle distance (meters).
 */
const distanceExpr = (alias, latParam, lngParam) => `
  (6371000 * 2 * asin(sqrt(
    power(sin((radians(${alias}.latitude) - radians($${latParam}::double precision)) / 2), 2) +
    cos(radians($${latParam}::double precision)) * cos(radians(${alias}.latitude)) *
    power(sin((radians(${alias}.longitude) - radians($${lngParam}::double precision)) / 2), 2)
  )))
`;

function roundCoord(value, decimals = 3) {
  const f = 10 ** decimals;
  return Math.round(Number(value) * f) / f;
}

router.get(
  '/nearest-banks',
  [
    query('lat').optional().isFloat({ min: -90, max: 90 }),
    query('lng').optional().isFloat({ min: -180, max: 180 }),
    query('address').optional().isString(),
    query('bloodGroup')
      .optional()
      .isIn(BLOOD_GROUPS),
    query('limit').optional().isInt({ min: 1, max: 50 }),
    query('minUnits').optional().isInt({ min: 1 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    let lat = req.query.lat ? parseFloat(req.query.lat) : null;
    let lng = req.query.lng ? parseFloat(req.query.lng) : null;
    const addressParam = req.query.address;

    if (addressParam) {
      const tryGeocode = async (addressStr) => {
        const googleApiKey = process.env.GOOGLE_MAPS_API_KEY;
        if (googleApiKey) {
          const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(addressStr)}&key=${googleApiKey}`;
          const r = await fetch(url);
          const d = await r.json();
          if (d.status === 'OK' && d.results.length > 0) {
            return { lat: d.results[0].geometry.location.lat, lng: d.results[0].geometry.location.lng };
          }
        } else {
          const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(addressStr)}&format=json&limit=1`;
          const r = await fetch(url, { headers: { 'User-Agent': 'BloodNow/1.0' } });
          const d = await r.json();
          if (d && d.length > 0) {
            return { lat: parseFloat(d[0].lat), lng: parseFloat(d[0].lon) };
          }
        }
        return null;
      };

      try {
        let coords = await tryGeocode(addressParam);
        if (!coords) {
          // Fallback 1: Try just the District and State (last two parts)
          const parts = addressParam.split(',').map((p) => p.trim()).filter(Boolean);
          if (parts.length >= 3) {
            const fallback = parts.slice(parts.length - 2).join(', ');
            coords = await tryGeocode(fallback);
          }
          // Fallback 2: Try just the State (last part)
          if (!coords && parts.length >= 2) {
            const fallback = parts[parts.length - 1];
            coords = await tryGeocode(fallback);
          }
        }
        if (coords) {
          lat = coords.lat;
          lng = coords.lng;
        }
      } catch (err) {
        console.error('Geocoding error:', err);
      }
    }

    if (lat === null || lng === null || isNaN(lat) || isNaN(lng)) {
      return res.status(400).json({ error: 'Valid latitude and longitude, or a valid address must be provided' });
    }

    const bloodGroup = req.query.bloodGroup || null;
    const limit = parseInt(req.query.limit, 10) || 10;
    const minUnits = parseInt(req.query.minUnits, 10) || 1;

    const dist = distanceExpr('bb', 1, 2);

    const sql = `
      SELECT bb.id, bb.name, bb.address_line, bb.latitude, bb.longitude,
             ${dist} AS distance_meters,
             COALESCE((SELECT units_available FROM blood_bank_inventory bi WHERE bi.blood_bank_id = bb.id AND bi.blood_group = $3), 0) AS available_units
      FROM blood_banks bb
      WHERE ($3::text IS NULL OR EXISTS (
        SELECT 1 FROM blood_bank_inventory bi
        WHERE bi.blood_bank_id = bb.id
          AND bi.blood_group = $3
          AND bi.units_available >= $5
      ))
      ORDER BY distance_meters ASC
      LIMIT $4
    `;

    try {
      const { rows } = await pool.query(sql, [lat, lng, bloodGroup, limit, minUnits]);

      if (rows.length === 0 && bloodGroup) {
        try {
          await pool.query(
            `INSERT INTO unfulfilled_searches (blood_group, latitude, longitude) VALUES ($1, $2, $3)`,
            [bloodGroup, lat, lng]
          );
        } catch (err) {
          console.error('Failed to log unfulfilled search', err);
        }
      }

      const uniqueResults = [];
      const seenNames = new Set();
      for (const r of rows) {
        if (!seenNames.has(r.name)) {
          seenNames.add(r.name);
          uniqueResults.push({
            id: r.id,
            name: r.name,
            addressLine: r.address_line,
            latitude: r.latitude,
            longitude: r.longitude,
            distanceMeters: Math.round(Number(r.distance_meters)),
            availableUnits: parseInt(r.available_units, 10) || 0,
          });
        }
      }

      return res.json({
        origin: { latitude: lat, longitude: lng },
        bloodGroupFilter: bloodGroup,
        results: uniqueResults,
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'Search failed' });
    }
  },
);

/** Authenticated requesters only; excludes self; masks phone; rounds coordinates for privacy */
router.get(
  '/nearest-donors',
  requireUser,
  [
    query('lat').isFloat({ min: -90, max: 90 }),
    query('lng').isFloat({ min: -180, max: 180 }),
    query('bloodGroup').isIn(BLOOD_GROUPS),
    query('limit').optional().isInt({ min: 1, max: 50 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const lat = parseFloat(req.query.lat);
    const lng = parseFloat(req.query.lng);
    const bloodGroup = req.query.bloodGroup;
    const limit = parseInt(req.query.limit, 10) || 10;
    const excludeId = req.auth.sub;

    const dist = distanceExpr('u', 1, 2);

    const sql = `
      SELECT u.id, u.full_name, u.blood_group, u.latitude, u.longitude, u.phone,
             ${dist} AS distance_meters
      FROM users u
      WHERE u.share_location_for_matching = true
        AND u.latitude IS NOT NULL
        AND u.longitude IS NOT NULL
        AND u.blood_group = $3
        AND u.id <> $5::bigint
      ORDER BY distance_meters ASC
      LIMIT $4
    `;

    try {
      const { rows } = await pool.query(sql, [
        lat,
        lng,
        bloodGroup,
        limit,
        excludeId,
      ]);
      return res.json({
        origin: { latitude: lat, longitude: lng },
        bloodGroup,
        results: rows.map((r) => ({
          id: r.id,
          fullName: r.full_name,
          bloodGroup: r.blood_group,
          approximateLatitude: roundCoord(r.latitude, 3),
          approximateLongitude: roundCoord(r.longitude, 3),
          distanceMeters: Math.round(Number(r.distance_meters)),
          phoneMasked: maskPhone(r.phone),
        })),
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: 'Search failed' });
    }
  },
);

export default router;
