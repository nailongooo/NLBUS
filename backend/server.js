require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const logger = require('./src/utils/logger');

const authRoutes = require('./src/routes/auth');
const routeRoutes = require('./src/routes/routes');
const tripRoutes = require('./src/routes/trips');
const feedbackRoutes = require('./src/routes/feedback');
const announcementRoutes = require('./src/routes/announcements');
const adminRoutes = require('./src/routes/admin');

const app = express();

app.use(helmet());
app.use(cors({ origin: (process.env.CORS_ORIGIN || '*').split(',') }));
app.use(express.json({ limit: '2mb' }));

// 基础的接口限流，防止恶意刷接口；众包定位上报单独放宽一些，因为行程中会比较频繁。
const generalLimiter = rateLimit({ windowMs: 60 * 1000, max: 120 });
const pingLimiter = rateLimit({ windowMs: 60 * 1000, max: 20 });
app.use('/api/trips', pingLimiter);
app.use('/api', generalLimiter);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/routes', routeRoutes);
app.use('/api/trips', tripRoutes);
app.use('/api/feedback', feedbackRoutes);
app.use('/api/announcements', announcementRoutes);
app.use('/api/admin', adminRoutes);

app.use((req, res) => {
  res.status(404).json({ message: '接口不存在' });
});

// 统一错误处理，避免未捕获异常直接让进程崩溃
app.use((err, req, res, next) => {
  logger.error(err.stack || String(err));
  res.status(500).json({ message: '服务器内部错误' });
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  logger.info(`服务已启动，监听端口 ${port}`);
});
