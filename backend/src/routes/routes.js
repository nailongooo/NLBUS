const express = require('express');
const { v4: uuidv4 } = require('uuid');
const pool = require('../db');
const { optionalUserAuth } = require('../middleware/auth');

const router = express.Router();

// 把数据库行转换成 iOS App 期望的 JSON 结构（字段名要和 Swift 里的 CodingKeys 完全对应）
function mapRoute(row, stops) {
  return {
    id: row.id,
    name: row.name,
    direction: row.direction,
    summary: row.summary,
    color_hex: row.color_hex,
    icon_system_name: row.icon_system_name,
    creator_id: row.creator_id,
    creator_display_name: row.creator_display_name,
    is_public: !!row.is_public,
    status: row.status,
    source: row.source,
    updated_at: new Date(row.updated_at).toISOString(),
    created_at: new Date(row.created_at).toISOString(),
    fare_description: row.fare_description,
    first_bus_time: row.first_bus_time,
    last_bus_time: row.last_bus_time,
    headway_minutes: row.headway_minutes,
    operator_company: row.operator_company,
    pre_alert_meters: row.pre_alert_meters,
    approaching_meters: row.approaching_meters,
    arrival_meters: row.arrival_meters,
    average_speed_kmh: row.average_speed_kmh,
    stops: (stops || []).map(mapStop)
  };
}

function mapStop(row) {
  return {
    id: row.id,
    route_id: row.route_id,
    name: row.name,
    order: row.stop_order,
    latitude: row.latitude,
    longitude: row.longitude
  };
}

async function fetchStopsForRoute(routeId) {
  const [stops] = await pool.query(
    'SELECT * FROM stops WHERE route_id = :routeId ORDER BY stop_order ASC',
    { routeId }
  );
  return stops;
}

// GET /api/routes?keyword=xxx  —— 搜索/列出公开路线（keyword 为空则返回全部公开路线）
router.get('/', async (req, res) => {
  const keyword = (req.query.keyword || '').trim();
  try {
    let rows;
    if (keyword) {
      const like = `%${keyword}%`;
      [rows] = await pool.query(
        `SELECT * FROM routes WHERE status = 'public' AND (name LIKE :like OR direction LIKE :like)
         ORDER BY updated_at DESC LIMIT 50`,
        { like }
      );
    } else {
      [rows] = await pool.query(
        `SELECT * FROM routes WHERE status = 'public' ORDER BY view_count DESC, updated_at DESC LIMIT 50`
      );
    }
    const result = [];
    for (const row of rows) {
      const stops = await fetchStopsForRoute(row.id);
      result.push(mapRoute(row, stops));
    }
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '获取路线列表失败' });
  }
});

// GET /api/routes/:id
router.get('/:id', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM routes WHERE id = :id', { id: req.params.id });
    if (rows.length === 0) return res.status(404).json({ message: '路线不存在' });
    await pool.query('UPDATE routes SET view_count = view_count + 1 WHERE id = :id', { id: req.params.id });
    const stops = await fetchStopsForRoute(req.params.id);
    res.json(mapRoute(rows[0], stops));
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '获取路线详情失败' });
  }
});

// POST /api/routes —— 创建路线（用户手动创建 / 上传文件导入 / 管理员录入都走这一个接口，
// 区别只在于请求体里的 source 字段和 is_public）
router.post('/', optionalUserAuth, async (req, res) => {
  const body = req.body;
  if (!body.name || !Array.isArray(body.stops) || body.stops.length < 2) {
    return res.status(400).json({ message: '路线名称不能为空，且至少需要 2 个站点' });
  }
  const deviceId = req.headers['x-device-id'] || null;
  const id = body.id && typeof body.id === 'string' ? body.id : uuidv4();
  const isPublic = !!body.is_public;
  const status = isPublic ? 'pending' : 'private';

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await conn.query(
      `INSERT INTO routes
        (id, name, direction, summary, color_hex, icon_system_name, creator_id, creator_display_name,
         is_public, status, source, fare_description, first_bus_time, last_bus_time, headway_minutes,
         operator_company, pre_alert_meters, approaching_meters, arrival_meters, average_speed_kmh)
       VALUES
        (:id, :name, :direction, :summary, :colorHex, :iconSystemName, :creatorId, :creatorDisplayName,
         :isPublic, :status, :source, :fareDescription, :firstBusTime, :lastBusTime, :headwayMinutes,
         :operatorCompany, :preAlertMeters, :approachingMeters, :arrivalMeters, :averageSpeedKmh)
       ON DUPLICATE KEY UPDATE
         name = VALUES(name), direction = VALUES(direction), summary = VALUES(summary),
         color_hex = VALUES(color_hex), fare_description = VALUES(fare_description),
         first_bus_time = VALUES(first_bus_time), last_bus_time = VALUES(last_bus_time),
         headway_minutes = VALUES(headway_minutes), operator_company = VALUES(operator_company)
      `,
      {
        id,
        name: body.name,
        direction: body.direction || '',
        summary: body.summary || null,
        colorHex: body.color_hex || '#3A7DFF',
        iconSystemName: body.icon_system_name || 'bus.fill',
        creatorId: body.creator_id || deviceId,
        creatorDisplayName: body.creator_display_name || null,
        isPublic,
        status,
        source: body.source || 'user_created',
        fareDescription: body.fare_description || null,
        firstBusTime: body.first_bus_time || null,
        lastBusTime: body.last_bus_time || null,
        headwayMinutes: body.headway_minutes || null,
        operatorCompany: body.operator_company || null,
        preAlertMeters: body.pre_alert_meters || 1500,
        approachingMeters: body.approaching_meters || 500,
        arrivalMeters: body.arrival_meters || 150,
        averageSpeedKmh: body.average_speed_kmh || 20
      }
    );

    await conn.query('DELETE FROM stops WHERE route_id = :id', { id });
    let order = 0;
    for (const stop of body.stops) {
      await conn.query(
        'INSERT INTO stops (id, route_id, name, stop_order, latitude, longitude) VALUES (:sid, :id, :name, :order, :lat, :lng)',
        { sid: uuidv4(), id, name: stop.name, order: order++, lat: stop.latitude, lng: stop.longitude }
      );
    }
    await conn.commit();

    const [rows] = await pool.query('SELECT * FROM routes WHERE id = :id', { id });
    const stops = await fetchStopsForRoute(id);
    res.json(mapRoute(rows[0], stops));
  } catch (err) {
    await conn.rollback();
    console.error(err);
    res.status(500).json({ message: '保存路线失败' });
  } finally {
    conn.release();
  }
});

// POST /api/routes/:id/submit —— 把一条私有路线提交公开审核
router.post('/:id/submit', async (req, res) => {
  try {
    await pool.query("UPDATE routes SET is_public = 1, status = 'pending' WHERE id = :id", { id: req.params.id });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ message: '提交失败' });
  }
});

// POST /api/routes/:id/report —— 举报路线
router.post('/:id/report', async (req, res) => {
  const deviceId = req.headers['x-device-id'] || null;
  try {
    await pool.query(
      'INSERT INTO route_reports (route_id, reason, device_id) VALUES (:routeId, :reason, :deviceId)',
      { routeId: req.params.id, reason: req.body.reason || '', deviceId }
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ message: '举报失败' });
  }
});

// GET /api/routes/:id/live-vehicles —— 众包车辆位置：取最近 5 分钟内每个设备最新的一条上报，聚合成"车辆"
router.get('/:id/live-vehicles', async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT t1.* FROM trip_pings t1
       INNER JOIN (
         SELECT device_id, MAX(reported_at) AS latest FROM trip_pings
         WHERE route_id = :routeId AND reported_at >= (NOW() - INTERVAL 5 MINUTE)
         GROUP BY device_id
       ) t2 ON t1.device_id = t2.device_id AND t1.reported_at = t2.latest
       WHERE t1.route_id = :routeId`,
      { routeId: req.params.id }
    );
    const result = rows.map(row => ({
      id: `${row.device_id}-${row.id}`,
      route_id: row.route_id,
      latitude: row.latitude,
      longitude: row.longitude,
      heading_degrees: row.heading_degrees,
      speed_kmh: row.speed_kmh,
      nearest_stop_order: null,
      reported_at: new Date(row.reported_at).toISOString()
    }));
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '获取实时车辆位置失败' });
  }
});

module.exports = router;
