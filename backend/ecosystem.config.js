// 如果你不想用 Docker，也可以直接用 PM2 在服务器上常驻运行：
//   npm install -g pm2
//   pm2 start ecosystem.config.js
//   pm2 save && pm2 startup
module.exports = {
  apps: [
    {
      name: 'bus-tracker-api',
      script: 'server.js',
      instances: 1,
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'production'
      }
    }
  ]
};
