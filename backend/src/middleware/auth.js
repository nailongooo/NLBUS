const jwt = require('jsonwebtoken');

/// 普通用户认证中间件：可选登录，token 无效或缺失时不会直接拒绝请求，
/// 而是把 req.user 设为 null，由具体路由自己决定这个接口是否强制要求登录。
function optionalUserAuth(req, res, next) {
  const header = req.headers.authorization;
  req.user = null;
  if (header && header.startsWith('Bearer ')) {
    const token = header.slice('Bearer '.length);
    try {
      req.user = jwt.verify(token, process.env.JWT_SECRET);
    } catch (err) {
      req.user = null;
    }
  }
  next();
}

function requireUserAuth(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ message: '需要登录后才能操作' });
  }
  next();
}

module.exports = { optionalUserAuth, requireUserAuth };
