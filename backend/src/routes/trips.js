const express = require('express');
const pool = require('../db');

const router = express.Router();

// POST /api/trips/ping —— 行程进行中，App 每隔一段时间上报一次匿名位置，
// 用作"众包车辆位置"的数据源。只存最近几分钟数据，定期用 scripts/cleanup-old-pings.js 清理。
router.post('/ping', async (req, res) => {
  const deviceId = req.headers['x-device-id'];
  const { routeId, latitude, longitude, speedKmh, headingDegrees } = req.body;
  if (!deviceId || !routeId || latitude == null || longitude == null) {
    return res.status(400).json({ message: '缺少必要字段' });
  }
  try {
    await pool.query(
      `INSERT INTO trip_pings (route_id, device_id, latitude, longitude, speed_kmh, heading_degrees)
       VALUES (:routeId, :deviceId, :latitude, :longitude, :speedKmh, :headingDegrees)`,
      { routeId, deviceId, latitude, longitude, speedKmh: speedKmh || null, headingDegrees: headingDegrees || null }
    );
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '上报位置失败' });
  }
});

module.exports = router;
