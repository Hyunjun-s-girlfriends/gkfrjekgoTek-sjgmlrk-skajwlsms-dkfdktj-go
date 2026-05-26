const mysql = require('mysql2/promise');

// 커넥션 풀 — 동시 요청이 많을 때 커넥션을 재사용하여 성능 유지
// connectionLimit: 10 → 동시 최대 10개 커넥션 (Docker MySQL 기본 설정에 맞춤)
const pool = mysql.createPool({
  host:     process.env.MYSQL_HOST         || '127.0.0.1',
  port:     process.env.MYSQL_PORT         || 3306,
  user:     process.env.MYSQL_APP_USER     || 'studypuls_app',
  password: process.env.MYSQL_APP_PASSWORD || '',
  database: process.env.MYSQL_DATABASE     || 'studypuls',
  charset: 'utf8mb4',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

module.exports = pool;
