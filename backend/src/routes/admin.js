const express = require('express');
const multer = require('multer');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { execFile } = require('child_process');
const path = require('path');
const pool = require('../db');
const { requireAdminAuth } = require('../middleware/adminAuth');
const { parseAdminCSV } = require('../utils/csvImport');
const { convertGTFSToRoutes } = require('../utils/gtfsImport');
const logger = require('../utils/logger');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// ---------- 登录 ----------
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  try {
    const [rows] = await pool.query('SELECT * FROM admin_users WHERE username = :username', { username });
    if (rows.length === 0) return res.status(401).json({ message: '用户名或密码错误' });
    const admin = rows[0];
    const matches = await bcrypt.compare(password, admin.password_hash);
    if (!matches) return res.status(401).json({ message: '用户名或密码错误' });
    const token = jwt.sign({ sub: admin.id, role: 'admin', username: admin.username }, process.env.JWT_SECRET, { expiresIn: '7d' });
    logger.info(`管理员 ${username} 登录成功`);
    res.json({ token });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '登录失败' });
  }
});

// 以下接口都需要管理员登录
router.use(requireAdminAuth);

// ---------- 数据概览 ----------
router.get('/stats', async (req, res) => {
  try {
    const [[{ totalRoutes }]] = await pool.query('SELECT COUNT(*) AS totalRoutes FROM routes');
    const [[{ pendingRoutes }]] = await pool.query("SELECT COUNT(*) AS pendingRoutes FROM routes WHERE status = 'pending'");
    const [[{ totalFeedback }]] = await pool.query('SELECT COUNT(*) AS totalFeedback FROM feedback');
    res.json({ total_routes: totalRoutes, pending_routes: pendingRoutes, total_feedback: totalFeedback });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '获取统计信息失败' });
  }
});

// ---------- 路线审核 ----------
router.get('/routes/pending', async (req, res) => {
  try {
    const [rows] = await pool.query("SELECT * FROM routes WHERE status = 'pending' ORDER BY created_at ASC");
    const result = [];
    for (const row of rows) {
      const [stops] = await pool.query('SELECT * FROM stops WHERE route_id = :id ORDER BY stop_order', { id: row.id });
      result.push({
        id: row.id, name: row.name, direction: row.direction, summary: row.summary,
        color_hex: row.color_hex, icon_system_name: row.icon_system_name,
        creator_id: row.creator_id, creator_display_name: row.creator_display_name,
        is_public: !!row.is_public, status: row.status, source: row.source,
        updated_at: new Date(row.updated_at).toISOString(), created_at: new Date(row.created_at).toISOString(),
        fare_description: row.fare_description, first_bus_time: row.first_bus_time, last_bus_time: row.last_bus_time,
        headway_minutes: row.headway_minutes, operator_company: row.operator_company,
        pre_alert_meters: row.pre_alert_meters, approaching_meters: row.approaching_meters,
        arrival_meters: row.arrival_meters, average_speed_kmh: row.average_speed_kmh,
        stops: stops.map(s => ({ id: s.id, route_id: s.route_id, name: s.name, order: s.stop_order, latitude: s.latitude, longitude: s.longitude }))
      });
    }
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '获取待审核路线失败' });
  }
});

router.post('/routes/:id/approve', async (req, res) => {
  try {
    await pool.query("UPDATE routes SET status = 'public', is_public = 1 WHERE id = :id", { id: req.params.id });
    logger.info(`管理员 ${req.admin.username} 通过了路线 ${req.params.id}`);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ message: '操作失败' });
  }
});

router.post('/routes/:id/reject', async (req, res) => {
  try {
    await pool.query("UPDATE routes SET status = 'rejected', is_public = 0 WHERE id = :id", { id: req.params.id });
    logger.info(`管理员 ${req.admin.username} 驳回了路线 ${req.params.id}`);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ message: '操作失败' });
  }
});

router.delete('/routes/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM routes WHERE id = :id', { id: req.params.id });
    logger.info(`管理员 ${req.admin.username} 删除了路线 ${req.params.id}`);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ message: '删除失败' });
  }
});

// ---------- 公告 ----------
router.post('/announcements', async (req, res) => {
  const { title, content } = req.body;
  const isPinned = req.body.is_pinned === 'true' || req.body.is_pinned === true;
  if (!title || !content) return res.status(400).json({ message: '标题和内容不能为空' });
  try {
    await pool.query(
      'INSERT INTO announcements (id, title, content, is_pinned) VALUES (:id, :title, :content, :isPinned)',
      { id: uuidv4(), title, content, isPinned }
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ message: '发布公告失败' });
  }
});

// ---------- 用户封禁（只有启用了账号体系才有意义）----------
router.post('/users/:id/ban', async (req, res) => {
  try {
    await pool.query('UPDATE users SET is_banned = 1 WHERE id = :id', { id: req.params.id });
    logger.info(`管理员 ${req.admin.username} 封禁了用户 ${req.params.id}`);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ message: '操作失败' });
  }
});

router.post('/users/:id/unban', async (req, res) => {
  try {
    await pool.query('UPDATE users SET is_banned = 0 WHERE id = :id', { id: req.params.id });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ message: '操作失败' });
  }
});

// ---------- 批量导入：CSV / JSON / GTFS ----------
// 导入后的路线默认状态为 public，因为都是管理员自己确认过的数据。
async function insertImportedRoutes(routes) {
  let count = 0;
  for (const r of routes) {
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      await conn.query(
        `INSERT INTO routes (id, name, direction, is_public, status, source, creator_display_name)
         VALUES (:id, :name, :direction, 1, 'public', 'gtfs_import', '管理员导入')`,
        { id: r.id, name: r.name, direction: r.direction || '' }
      );
      let order = 0;
      for (const stop of r.stops) {
        await conn.query(
          'INSERT INTO stops (id, route_id, name, stop_order, latitude, longitude) VALUES (:sid, :id, :name, :order, :lat, :lng)',
          { sid: uuidv4(), id: r.id, name: stop.name, order: order++, lat: stop.latitude, lng: stop.longitude }
        );
      }
      await conn.commit();
      count++;
    } catch (err) {
      await conn.rollback();
      console.error('导入路线失败：', r.name, err.message);
    } finally {
      conn.release();
    }
  }
  return count;
}

router.post('/import/csv', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ message: '请上传 CSV 文件' });
  try {
    const routes = parseAdminCSV(req.file.buffer.toString('utf-8'));
    const count = await insertImportedRoutes(routes);
    logger.info(`管理员 ${req.admin.username} 通过 CSV 导入了 ${count} 条路线`);
    res.json({ imported: count });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.post('/import/json', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ message: '请上传 JSON 文件' });
  try {
    const payload = JSON.parse(req.file.buffer.toString('utf-8'));
    const list = Array.isArray(payload) ? payload : [payload];
    const routes = list.map(r => ({ id: uuidv4(), name: r.name, direction: r.direction || '', stops: r.stops || [] }));
    const count = await insertImportedRoutes(routes);
    logger.info(`管理员 ${req.admin.username} 通过 JSON 导入了 ${count} 条路线`);
    res.json({ imported: count });
  } catch (err) {
    res.status(400).json({ message: 'JSON 解析失败：' + err.message });
  }
});

// GTFS：需要同时上传 routes.txt / stops.txt / trips.txt / stop_times.txt 四个文件
router.post(
  '/import/gtfs',
  upload.fields([
    { name: 'routes', maxCount: 1 },
    { name: 'stops', maxCount: 1 },
    { name: 'trips', maxCount: 1 },
    { name: 'stop_times', maxCount: 1 }
  ]),
  async (req, res) => {
    const files = req.files || {};
    if (!files.routes || !files.stops || !files.trips || !files.stop_times) {
      return res.status(400).json({ message: '需要同时上传 routes.txt / stops.txt / trips.txt / stop_times.txt 四个文件' });
    }
    try {
      const routes = convertGTFSToRoutes({
        routesTxt: files.routes[0].buffer.toString('utf-8'),
        stopsTxt: files.stops[0].buffer.toString('utf-8'),
        tripsTxt: files.trips[0].buffer.toString('utf-8'),
        stopTimesTxt: files.stop_times[0].buffer.toString('utf-8')
      });
      const count = await insertImportedRoutes(routes);
      logger.info(`管理员 ${req.admin.username} 通过 GTFS 导入了 ${count} 条路线`);
      res.json({ imported: count, parsed: routes.length });
    } catch (err) {
      console.error(err);
      res.status(400).json({ message: 'GTFS 解析失败：' + err.message });
    }
  }
);

// ---------- 导出数据库（需要服务器上装有 mysqldump） ----------
router.get('/export', (req, res) => {
  const args = [
    `-h${process.env.DB_HOST || '127.0.0.1'}`,
    `-P${process.env.DB_PORT || 3306}`,
    `-u${process.env.DB_USER}`,
    `-p${process.env.DB_PASSWORD}`,
    process.env.DB_NAME
  ];
  execFile('mysqldump', args, { maxBuffer: 1024 * 1024 * 100 }, (err, stdout) => {
    if (err) {
      console.error(err);
      return res.status(500).json({ message: '导出失败，请确认服务器已安装 mysqldump：' + err.message });
    }
    res.setHeader('Content-Type', 'application/sql');
    res.setHeader('Content-Disposition', `attachment; filename="bus_tracker_${Date.now()}.sql"`);
    res.send(stdout);
  });
});

// ---------- 运行日志 ----------
router.get('/logs', (req, res) => {
  const lines = logger.readLastLines(300);
  res.json({ lines });
});

module.exports = router;
