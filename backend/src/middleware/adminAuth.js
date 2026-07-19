const jwt = require('jsonwebtoken');

/// 管理员认证中间件：与普通用户 token 完全分开的签发体系（payload 里带 role: 'admin'）。
function requireAdminAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ message: '缺少管理员登录凭证' });
  }
  const token = header.slice('Bearer '.length);
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    if (payload.role !== 'admin') {
      return res.status(403).json({ message: '没有管理员权限' });
    }
    req.admin = payload;
    next();
  } catch (err) {
    return res.status(401).json({ message: '登录凭证已失效，请重新登录' });
  }
}

module.exports = { requireAdminAuth };
