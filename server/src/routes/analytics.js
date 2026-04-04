import { Router } from 'express';
import { pool } from '../db/pool.js';

const router = Router();

router.get('/dashboard', async (req, res) => {
  const token = req.headers['x-govt-token'];
  if (token !== 'admin123') {
    return res.status(401).json({ error: 'Unauthorized. Official government access only.' });
  }

  try {
    // 1. High Demand Areas (Banks with highest total historical requests)
    const { rows: demandRows } = await pool.query(`
      SELECT b.id, b.name, b.address_line, b.latitude, b.longitude,
             COUNT(r.id) as total_requests,
             SUM(r.units_needed) as total_units_needed
      FROM blood_banks b
      JOIN blood_requests r ON r.blood_bank_id = b.id
      GROUP BY b.id, b.name, b.address_line, b.latitude, b.longitude
      ORDER BY total_requests DESC
      LIMIT 10
    `);

    // 2. Shortages (Compare total units available vs total units needed per blood group)
    const { rows: inventoryRows } = await pool.query(`
      SELECT blood_group, SUM(units_available) as total_available
      FROM blood_bank_inventory
      GROUP BY blood_group
    `);
    
    const { rows: neededRows } = await pool.query(`
      SELECT blood_group, SUM(units_needed) as total_needed
      FROM blood_requests
      WHERE status = 'pending'
      GROUP BY blood_group
    `);

    // Merge shortages data into a clean structure
    const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    const shortages = bloodGroups.map(bg => {
      const available = inventoryRows.find(r => r.blood_group === bg);
      const needed = neededRows.find(r => r.blood_group === bg);
      const availNum = available ? Number(available.total_available) : 0;
      const neededNum = needed ? Number(needed.total_needed) : 0;
      return {
        bloodGroup: bg,
        totalAvailable: availNum,
        totalNeeded: neededNum,
        shortage: neededNum > availNum ? neededNum - availNum : 0
      };
    }).sort((a, b) => b.shortage - a.shortage);

    // 3. Emergency Hotspots (All pending unfulfilled requests)
    const { rows: emergencyRows } = await pool.query(`
      SELECT r.id, r.patient_name, r.blood_group, r.units_needed, r.created_at,
             b.name as bank_name, b.address_line, b.latitude, b.longitude
      FROM blood_requests r
      JOIN blood_banks b ON r.blood_bank_id = b.id
      WHERE r.status = 'pending'
      ORDER BY r.units_needed DESC, r.created_at DESC
      LIMIT 15
    `);

    // 4. Unmet Needs Hotspots (Failed Searches)
    const { rows: unmetNeedsRows } = await pool.query(`
      SELECT ROUND(latitude::numeric, 3) as approx_lat, 
             ROUND(longitude::numeric, 3) as approx_lng, 
             blood_group, 
             COUNT(*) as fail_count
      FROM unfulfilled_searches
      WHERE latitude IS NOT NULL AND longitude IS NOT NULL
      GROUP BY approx_lat, approx_lng, blood_group
      ORDER BY fail_count DESC
      LIMIT 15
    `);

    // 5. Most requested blood groups
    const { rows: groupRows } = await pool.query(`
      SELECT blood_group, COUNT(*) as count 
      FROM blood_requests 
      GROUP BY blood_group 
      ORDER BY count DESC
    `);

    // 6. Requests by locality (top 5)
    const { rows: localityRows } = await pool.query(`
      SELECT b.address_line as locality, COUNT(r.id) as count 
      FROM blood_requests r 
      JOIN blood_banks b ON r.blood_bank_id = b.id 
      WHERE b.address_line IS NOT NULL 
      GROUP BY b.address_line 
      ORDER BY count DESC 
      LIMIT 5
    `);

    // 7. Daily request trend for last 30 days
    const { rows: trendRows } = await pool.query(`
      SELECT DATE(created_at) as date, COUNT(*) as count 
      FROM blood_requests 
      WHERE created_at >= NOW() - INTERVAL '30 days' 
      GROUP BY DATE(created_at) 
      ORDER BY DATE(created_at) ASC
    `);

    // 8. Summary Stats
    const { rows: donorRows } = await pool.query(`SELECT COUNT(*) as count FROM users`);
    const { rows: requestRows } = await pool.query(`SELECT COUNT(*) as count FROM blood_requests`);
    const { rows: fulfilledRows } = await pool.query(`SELECT COUNT(*) as count FROM blood_requests WHERE status = 'fulfilled'`);
    const { rows: pendingRows } = await pool.query(`SELECT COUNT(*) as count FROM blood_requests WHERE status = 'pending'`);

    return res.json({
      highDemandAreas: demandRows,
      shortages: shortages,
      emergencyHotspots: emergencyRows,
      unmetNeedsHotspots: unmetNeedsRows,
      mostRequestedGroups: groupRows.map(r => ({ bloodGroup: r.blood_group, count: Number(r.count) })),
      requestsByLocality: localityRows.map(r => ({ locality: r.locality, count: Number(r.count) })),
      dailyTrend: trendRows.map(r => ({ date: new Date(r.date).toISOString(), count: Number(r.count) })),
      summary: {
        totalDonors: Number(donorRows[0].count),
        totalRequests: Number(requestRows[0].count),
        fulfilledRequests: Number(fulfilledRows[0].count),
        pendingRequests: Number(pendingRows[0].count)
      }
    });
  } catch (e) {
    console.error('Analytics Error:', e);
    return res.status(500).json({ error: 'Failed to load analytics dashboard data' });
  }
});

export default router;
