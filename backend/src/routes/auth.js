const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const pool = require('../db');

const router = express.Router();

// 注册（可选账号体系：整个 App 不强制要求这个）
router.post('/register', async (req, res) => {
  const { email, password, nickname } = req.body;
  if (!email || !password || !nickname) {
    return res.status(400).json({ message: '邮箱、密码、昵称都不能为空' });
  }
  if (password.length < 6) {
    return res.status(400).json({ message: '密码至少需要 6 位' });
  }
  try {
    const [existing] = await pool.query('SELECT id FROM users WHERE email = :email', { email });
    if (existing.length > 0) {
      return res.status(409).json({ message: '该邮箱已经注册过了' });
    }
    const id = uuidv4();
    const passwordHash = await bcrypt.hash(password, 10);
    await pool.query(
      'INSERT INTO users (id, email, password_hash, nickname) VALUES (:id, :email, :passwordHash, :nickname)',
      { id, email, passwordHash, nickname }
    );
    const token = jwt.sign({ sub: id, role: 'user' }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.json({ id, email, nickname, token, is_admin: false });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '注册失败，请稍后重试' });
  }
});

// 登录
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ message: '请输入邮箱和密码' });
  }
  try {
    const [rows] = await pool.query('SELECT * FROM users WHERE email = :email', { email });
    if (rows.length === 0) {
      return res.status(401).json({ message: '邮箱或密码不正确' });
    }
    const user = rows[0];
    if (user.is_banned) {
      return res.status(403).json({ message: '该账号已被封禁' });
    }
    const matches = await bcrypt.compare(password, user.password_hash);
    if (!matches) {
      return res.status(401).json({ message: '邮箱或密码不正确' });
    }
    const token = jwt.sign({ sub: user.id, role: 'user' }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.json({ id: user.id, email: user.email, nickname: user.nickname, token, is_admin: false });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: '登录失败，请稍后重试' });
  }
});

module.exports = router;
