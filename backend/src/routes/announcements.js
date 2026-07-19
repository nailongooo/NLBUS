const express = require('express');
const pool = require('../db');

const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM announcements ORDER BY is_pinned DESC, created_at DESC LIMIT 20'
    );
    res.json(rows.map(row => ({
      id: row.id,
      title: row.title,
      content: row.content,
      created_at: new Date(row.created_at).toISOString(),
      is_pinned: !!row.is_pinned
    })));
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '获取公告失败' });
  }
});

module.exports = router;
