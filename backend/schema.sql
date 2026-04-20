DROP TABLE IF EXISTS otp_codes;
DROP TABLE IF EXISTS auth_tokens;
DROP TABLE IF EXISTS user_settings;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  display_name VARCHAR(120) DEFAULT NULL,
  email_verified TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE auth_tokens (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  revoked_at TIMESTAMP NULL DEFAULT NULL,
  INDEX idx_auth_tokens_user_id (user_id),
  INDEX idx_auth_tokens_expires_at (expires_at),
  CONSTRAINT fk_auth_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE otp_codes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  purpose VARCHAR(32) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  consumed_at TIMESTAMP NULL DEFAULT NULL,
  attempts INT NOT NULL DEFAULT 0,
  INDEX idx_otp_codes_user_purpose (user_id, purpose),
  INDEX idx_otp_codes_expires_at (expires_at),
  CONSTRAINT fk_otp_codes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE user_settings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  daily_limit_minutes INT NOT NULL DEFAULT 60,
  cooldown_minutes INT NOT NULL DEFAULT 30,
  extra_unlock_minutes INT NOT NULL DEFAULT 15,
  max_unlocks_per_day INT NOT NULL DEFAULT 1,
  monitored_apps_json JSON NOT NULL,
  lock_schedule_enabled TINYINT(1) NOT NULL DEFAULT 0,
  schedule_start_hour INT NOT NULL DEFAULT 8,
  schedule_start_minute INT NOT NULL DEFAULT 0,
  schedule_end_hour INT NOT NULL DEFAULT 22,
  schedule_end_minute INT NOT NULL DEFAULT 0,
  accelerometer_enabled TINYINT(1) NOT NULL DEFAULT 1,
  wake_hour INT NOT NULL DEFAULT 7,
  wake_minute INT NOT NULL DEFAULT 0,
  sleep_hour INT NOT NULL DEFAULT 23,
  sleep_minute INT NOT NULL DEFAULT 0,
  notifications_enabled TINYINT(1) NOT NULL DEFAULT 1,
  unlocks_used_today INT NOT NULL DEFAULT 0,
  unlock_day_key CHAR(10) DEFAULT NULL,
  cooldown_end_at DATETIME DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_user_settings_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
