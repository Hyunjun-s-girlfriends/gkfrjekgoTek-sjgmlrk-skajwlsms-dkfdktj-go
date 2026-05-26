-- admin 유저 생성 (schema 관리용, 앱 서버는 studypuls_app 사용)
CREATE USER IF NOT EXISTS 'studypuls_admin'@'%' IDENTIFIED BY 'AdminCherryPulse!2026';
GRANT ALL PRIVILEGES ON studypuls.* TO 'studypuls_admin'@'%';
FLUSH PRIVILEGES;
