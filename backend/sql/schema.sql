-- 出行提醒 App 后端数据库结构
-- 使用方法见 docs/03-后端部署教程.md
-- 字符集统一使用 utf8mb4，避免中文/表情符号乱码

CREATE DATABASE IF NOT EXISTS bus_tracker
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE bus_tracker;

-- 可选的普通用户账号表（App 默认不强制登录，只有主动注册才会用到）
CREATE TABLE IF NOT EXISTS users (
  id CHAR(36) PRIMARY KEY,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  nickname VARCHAR(60) NOT NULL,
  is_banned TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 管理员账号表，与普通用户账号体系完全分开
CREATE TABLE IF NOT EXISTS admin_users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(60) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 路线主表
CREATE TABLE IF NOT EXISTS routes (
  id CHAR(36) PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  direction VARCHAR(160) NOT NULL DEFAULT '',
  summary TEXT,
  color_hex VARCHAR(9) NOT NULL DEFAULT '#3A7DFF',
  icon_system_name VARCHAR(60) NOT NULL DEFAULT 'bus.fill',
  creator_id VARCHAR(80),
  creator_display_name VARCHAR(60),
  is_public TINYINT(1) NOT NULL DEFAULT 0,
  status ENUM('private','pending','public','rejected') NOT NULL DEFAULT 'private',
  source ENUM('builtin','user_created','user_uploaded','server_official','gtfs_import') NOT NULL DEFAULT 'user_created',
  fare_description VARCHAR(255),
  first_bus_time VARCHAR(20),
  last_bus_time VARCHAR(20),
  headway_minutes INT,
  operator_company VARCHAR(120),
  pre_alert_meters DOUBLE NOT NULL DEFAULT 1500,
  approaching_meters DOUBLE NOT NULL DEFAULT 500,
  arrival_meters DOUBLE NOT NULL DEFAULT 150,
  average_speed_kmh DOUBLE NOT NULL DEFAULT 20,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  view_count INT NOT NULL DEFAULT 0,
  INDEX idx_status (status),
  INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 站点表（属于某条路线）
CREATE TABLE IF NOT EXISTS stops (
  id CHAR(36) PRIMARY KEY,
  route_id CHAR(36) NOT NULL,
  name VARCHAR(120) NOT NULL,
  stop_order INT NOT NULL,
  latitude DOUBLE NOT NULL,
  longitude DOUBLE NOT NULL,
  FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE,
  INDEX idx_route (route_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 举报记录
CREATE TABLE IF NOT EXISTS route_reports (
  id INT PRIMARY KEY AUTO_INCREMENT,
  route_id CHAR(36) NOT NULL,
  reason TEXT,
  device_id VARCHAR(80),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 众包车辆位置上报（短期数据，定期清理，只保留最近几分钟用于聚合展示）
CREATE TABLE IF NOT EXISTS trip_pings (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  route_id CHAR(36) NOT NULL,
  device_id VARCHAR(80) NOT NULL,
  latitude DOUBLE NOT NULL,
  longitude DOUBLE NOT NULL,
  speed_kmh DOUBLE,
  heading_degrees DOUBLE,
  reported_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_route_time (route_id, reported_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户反馈
CREATE TABLE IF NOT EXISTS feedback (
  id INT PRIMARY KEY AUTO_INCREMENT,
  content TEXT NOT NULL,
  contact VARCHAR(120),
  device_id VARCHAR(80),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 公告
CREATE TABLE IF NOT EXISTS announcements (
  id CHAR(36) PRIMARY KEY,
  title VARCHAR(160) NOT NULL,
  content TEXT NOT NULL,
  is_pinned TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 注意：这里不预置管理员账号密码（避免给一个"看起来能用但实际上验证不通过"的假哈希）。
-- 请在部署完后端之后，运行一次：
--   node scripts/create-admin.js <用户名> <密码>
-- 脚本会用 bcrypt 现场生成正确的密码哈希并写入 admin_users 表。
