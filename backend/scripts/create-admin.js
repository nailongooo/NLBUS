// 用法：node scripts/create-admin.js <用户名> <密码>
// 会用 bcrypt 现场生成密码哈希并写入 / 更新 admin_users 表。
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const bcrypt = require('bcryptjs');
const pool = require('../src/db');

async function main() {
  const [, , username, password] = process.argv;
  if (!username || !password) {
    console.log('用法：node scripts/create-admin.js <用户名> <密码>');
    process.exit(1);
  }
  if (password.length < 8) {
    console.log('为了安全，密码请至少设置 8 位');
    process.exit(1);
  }
  const passwordHash = await bcrypt.hash(password, 10);
  await pool.query(
    `INSERT INTO admin_users (username, password_hash) VALUES (:username, :passwordHash)
     ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash)`,
    { username, passwordHash }
  );
  console.log(`管理员账号 "${username}" 创建/更新成功`);
  process.exit(0);
}

main().catch(err => {
  console.error('创建管理员失败：', err);
  process.exit(1);
});
