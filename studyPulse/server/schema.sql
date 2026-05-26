CREATE DATABASE IF NOT EXISTS studypuls;
USE studypuls;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  google_id VARCHAR(255) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  profile_image VARCHAR(500),
  description TEXT,
  organization VARCHAR(255),
  level INT DEFAULT 1,
  px INT DEFAULT 0,
  streak_days INT DEFAULT 0,
  max_streak_days INT DEFAULT 0,
  last_login_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS subjects (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  color VARCHAR(7) DEFAULT '#007AFF',
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS timer_sessions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  subject_id INT,
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP,
  duration_seconds INT DEFAULT 0,
  session_date DATE NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS hrv_data (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  hrv_sdnn FLOAT,
  heart_rate INT,
  stress_index FLOAT COMMENT '0~100, higher = more stress',
  recorded_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `groups` (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  icon VARCHAR(50) DEFAULT 'book.fill',
  invite_code VARCHAR(20) UNIQUE NOT NULL,
  owner_id INT NOT NULL,
  max_members INT DEFAULT 8,
  total_px INT DEFAULT 0,
  mission_clear_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS group_members (
  id INT AUTO_INCREMENT PRIMARY KEY,
  group_id INT NOT NULL,
  user_id INT NOT NULL,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_member (group_id, user_id),
  FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS group_messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  group_id INT NOT NULL,
  user_id INT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (group_id) REFERENCES `groups`(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS missions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  type ENUM('personal', 'group') DEFAULT 'personal',
  mission_type ENUM('study_time', 'stress_level', 'streak', 'group_study') NOT NULL,
  target_value FLOAT NOT NULL,
  px_reward INT DEFAULT 50,
  is_daily BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mission_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  mission_id INT NOT NULL,
  user_id INT NOT NULL,
  group_id INT,
  completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  px_earned INT DEFAULT 0,
  FOREIGN KEY (mission_id) REFERENCES missions(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 기본 미션 데이터 (INSERT IGNORE: 스키마 재실행 시 중복 삽입 방지)
INSERT IGNORE INTO missions (title, description, type, mission_type, target_value, px_reward) VALUES
  ('1시간 공부하기', '오늘 총 1시간 이상 공부하기', 'personal', 'study_time', 3600, 30),
  ('2시간 공부하기', '오늘 총 2시간 이상 공부하기', 'personal', 'study_time', 7200, 60),
  ('스트레스 낮추기', '스트레스 지수 50 미만 유지하기', 'personal', 'stress_level', 50, 40),
  ('3일 연속 접속', '3일 연속으로 앱 접속하기', 'personal', 'streak', 3, 100),
  ('그룹 함께 공부', '그룹원과 함께 총 5시간 공부하기', 'group', 'group_study', 18000, 200);
