class AppConstants {
  AppConstants._();

  // SharedPreferences keys
  static const String keyIsOnboarded = 'is_onboarded';
  static const String keyDailyLimitMinutes = 'daily_limit_minutes';
  static const String keyCooldownMinutes = 'cooldown_minutes';
  static const String keyMonitoredApps = 'monitored_apps';
  static const String keySecurityQuestion = 'security_question';
  static const String keySecurityAnswer = 'security_answer';
  static const String keySecurityQuestion2 = 'security_question_2';
  static const String keySecurityAnswer2 = 'security_answer_2';
  static const String keyExtraUnlockMinutes = 'extra_unlock_minutes';
  static const String keyMaxUnlocksPerDay = 'max_unlocks_per_day';
  static const String keyLockScheduleEnabled = 'lock_schedule_enabled';
  static const String keyScheduleStartHour = 'schedule_start_hour';
  static const String keyScheduleEndHour = 'schedule_end_hour';
  static const String keyTodayUnlockCount = 'today_unlock_count';
  static const String keyLastUnlockDate = 'last_unlock_date';
  static const String keyIsLocked = 'is_locked';
  static const String keyCooldownEndTime = 'cooldown_end_time';
  static const String keyChallengeCode = 'challenge_code';
  static const String keyAccelerometerEnabled = 'accelerometer_enabled';
  static const String keyPickupCount = 'pickup_count_today';
  static const String keyLastPickupDate = 'last_pickup_date';
  static const String keyUserName = 'user_name';
  static const String keyWakeHour = 'wake_hour';
  static const String keySleepHour = 'sleep_hour';

  // Secure storage keys
  static const String securePin = 'focuslock_pin';
  static const int pinLength = 6;

  // Defaults
  static const int defaultDailyLimitMinutes = 60;
  static const int defaultCooldownMinutes = 30;
  static const int defaultExtraUnlockMinutes = 15;
  static const int defaultMaxUnlocksPerDay = 1;
  static const int checkIntervalSeconds = 30;

  // Notification IDs
  static const int notifIdApproaching75 = 1;
  static const int notifIdApproaching90 = 2;
  static const int notifIdLimitReached = 3;
  static const int notifIdForegroundService = 999;

  // Security questions
  static const List<String> securityQuestions = [
    "What is the name of your first pet?",
    "What city were you born in?",
    "What is your mother's maiden name?",
    "What was the name of your first school?",
    "What is your favourite movie?",
    "What is your oldest sibling's middle name?",
    "What was your childhood nickname?",
    "What is the first name of your best friend from school?",
    "What was the first concert you attended?",
    "What is your favourite teacher's surname?",
    "What was the make of your first bicycle?",
    "What street did you grow up on?",
    "What was your dream job as a child?",
    "What is your favourite book?",
  ];
}
