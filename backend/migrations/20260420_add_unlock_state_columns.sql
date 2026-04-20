ALTER TABLE user_settings
  ADD COLUMN unlocks_used_today INT NOT NULL DEFAULT 0 AFTER notifications_enabled,
  ADD COLUMN unlock_day_key CHAR(10) DEFAULT NULL AFTER unlocks_used_today,
  ADD COLUMN cooldown_end_at DATETIME DEFAULT NULL AFTER unlock_day_key;
