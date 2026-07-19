// 用法：node scripts/cleanup-old-pings.js
// 建议用 crontab 每隔几分钟跑一次，清理超过 30 分钟的众包定位数据，避免表越滚越大，
// 也是对用户位置隐私数据"尽量少留存"的负责任做法。
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const pool = require('../src/db');

async function main() {
  const [result] = await pool.query(
    "DELETE FROM trip_pings WHERE reported_at < (NOW() - INTERVAL 30 MINUTE)"
  );
  console.log(`已清理 ${result.affectedRows} 条过期的众包定位数据`);
  process.exit(0);
}

main().catch(err => {
  console.error('清理失败：', err);
  process.exit(1);
});
