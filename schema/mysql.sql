CREATE TABLE users (
  id VARCHAR(64) PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  email VARCHAR(120) UNIQUE,
  name VARCHAR(50) NOT NULL,
  phone VARCHAR(20) UNIQUE,
  provider VARCHAR(30) NOT NULL,
  role ENUM('USER', 'ADMIN') NOT NULL DEFAULT 'USER',
  xp INT NOT NULL DEFAULT 0,
  credits INT NOT NULL DEFAULT 0,
  title VARCHAR(60) NOT NULL DEFAULT '새싹 학습자',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_profiles (
  user_id VARCHAR(64) PRIMARY KEY,
  avatar_url TEXT,
  tags JSON,
  bio TEXT,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE subjects (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64),
  name VARCHAR(50) NOT NULL,
  color VARCHAR(20),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE watch_devices (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  device_name VARCHAR(100) NOT NULL,
  device_type ENUM('APPLE_WATCH_BRIDGE', 'AIRPODS', 'MANUAL') NOT NULL DEFAULT 'APPLE_WATCH_BRIDGE',
  status ENUM('waiting', 'connected', 'error') NOT NULL DEFAULT 'waiting',
  bridge_mode BOOLEAN NOT NULL DEFAULT FALSE,
  last_synced_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE study_sessions (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  subject_id VARCHAR(64) NOT NULL,
  started_at DATETIME NOT NULL,
  ended_at DATETIME,
  total_minutes INT NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (subject_id) REFERENCES subjects(id)
);

CREATE TABLE biometric_samples (
  id VARCHAR(64) PRIMARY KEY,
  session_id VARCHAR(64) NOT NULL,
  device_id VARCHAR(64),
  heart_rate INT NOT NULL,
  hrv INT NOT NULL,
  stress_score INT NOT NULL,
  focus_score INT NOT NULL,
  recorded_at DATETIME NOT NULL,
  FOREIGN KEY (session_id) REFERENCES study_sessions(id),
  FOREIGN KEY (device_id) REFERENCES watch_devices(id)
);

CREATE TABLE motion_events (
  id VARCHAR(64) PRIMARY KEY,
  session_id VARCHAR(64),
  device_id VARCHAR(64),
  pitch DECIMAL(8, 4),
  roll DECIMAL(8, 4),
  yaw DECIMAL(8, 4),
  sleepy_score INT NOT NULL DEFAULT 0,
  down_duration_seconds INT NOT NULL DEFAULT 0,
  source VARCHAR(50) NOT NULL DEFAULT 'airpods-core-motion',
  event_type ENUM('sample', 'drowsy') NOT NULL DEFAULT 'sample',
  detected_at DATETIME NOT NULL,
  FOREIGN KEY (session_id) REFERENCES study_sessions(id),
  FOREIGN KEY (device_id) REFERENCES watch_devices(id)
);

CREATE TABLE study_groups (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  invite_code VARCHAR(20) UNIQUE NOT NULL,
  created_by VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES users(id)
);

CREATE TABLE group_members (
  group_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'member',
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (group_id, user_id),
  FOREIGN KEY (group_id) REFERENCES study_groups(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE group_missions (
  id VARCHAR(64) PRIMARY KEY,
  group_id VARCHAR(64) NOT NULL,
  title VARCHAR(120) NOT NULL,
  type VARCHAR(50) NOT NULL,
  target INT NOT NULL,
  reward_credits INT NOT NULL DEFAULT 0,
  starts_at DATETIME,
  ends_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (group_id) REFERENCES study_groups(id)
);

CREATE TABLE missions (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  title VARCHAR(120) NOT NULL,
  type VARCHAR(50) NOT NULL,
  target INT NOT NULL,
  reward_xp INT NOT NULL DEFAULT 0,
  reward_credits INT NOT NULL DEFAULT 0,
  title_reward VARCHAR(60),
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE mission_logs (
  id VARCHAR(64) PRIMARY KEY,
  mission_id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at DATETIME,
  FOREIGN KEY (mission_id) REFERENCES missions(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE titles (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(60) NOT NULL UNIQUE,
  condition_text TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_titles (
  user_id VARCHAR(64) NOT NULL,
  title_id VARCHAR(64) NOT NULL,
  equipped BOOLEAN NOT NULL DEFAULT FALSE,
  acquired_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, title_id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (title_id) REFERENCES titles(id)
);

CREATE TABLE ai_reports (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  summary TEXT NOT NULL,
  insight TEXT NOT NULL,
  next_plan JSON,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE chat_messages (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  role ENUM('user', 'assistant') NOT NULL,
  message TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE notification_settings (
  user_id VARCHAR(64) PRIMARY KEY,
  focus_alert BOOLEAN NOT NULL DEFAULT TRUE,
  mission_alert BOOLEAN NOT NULL DEFAULT TRUE,
  drowsiness_alert BOOLEAN NOT NULL DEFAULT TRUE,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE notification_events (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  message TEXT NOT NULL,
  sent_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  read_at DATETIME,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE sms_verifications (
  id VARCHAR(64) PRIMARY KEY,
  phone VARCHAR(20) NOT NULL,
  code_hash VARCHAR(255) NOT NULL,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
