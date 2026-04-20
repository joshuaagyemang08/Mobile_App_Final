ALTER TABLE user_settings
  ADD COLUMN schedule_start_minute INT NOT NULL DEFAULT 0 AFTER schedule_start_hour,
  ADD COLUMN schedule_end_minute INT NOT NULL DEFAULT 0 AFTER schedule_end_hour,
  ADD COLUMN wake_minute INT NOT NULL DEFAULT 0 AFTER wake_hour,
  ADD COLUMN sleep_minute INT NOT NULL DEFAULT 0 AFTER sleep_hour,
  ADD COLUMN notifications_enabled TINYINT(1) NOT NULL DEFAULT 1 AFTER sleep_minute;
