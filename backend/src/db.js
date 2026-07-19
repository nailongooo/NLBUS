const mysql = require('mysql2/promise');
require('dotenv').config();

// 统一的数据库连接池。所有 routes/*.js 都从这里拿连接，避免每个请求都重新建连接。
const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  namedPlaceholders: true,
  dateStrings: false
});

module.exports = pool;
