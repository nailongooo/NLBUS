const express = require('express');
const pool = require('../db');

const router = express.Router();

router.post('/', async (req, res) => {
  const deviceId = req.headers['x-device-id'] || null;
  const { content, contact } = req.body;
  if (!content || !content.trim()) {
    return res.status(400).json({ message: '反馈内容不能为空' });
  }
  try {
    await pool.query(
      'INSERT INTO feedback (content, contact, device_id) VALUES (:content, :contact, :deviceId)',
      { content, contact: contact || null, deviceId }
    );
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '提交反馈失败' });
  }
});

module.exports = router;
