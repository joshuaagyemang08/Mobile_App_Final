class UserSettings {
  final String userName;
  final int dailyLimitMinutes;
  final int cooldownMinutes;
  final int extraUnlockMinutes;
  final int maxUnlocksPerDay;
  final List<String> monitoredApps;
  final String securityQuestion;
  final String securityAnswer;
  final String securityQuestion2;
  final String securityAnswer2;
  final bool lockScheduleEnabled;
  final int scheduleStartHour;
  final int scheduleEndHour;
  final bool accelerometerEnabled;
  final int wakeHour;
  final int sleepHour;

  const UserSettings({
    required this.userName,
    required this.dailyLimitMinutes,
    required this.cooldownMinutes,
    required this.extraUnlockMinutes,
    required this.maxUnlocksPerDay,
    required this.monitoredApps,
    required this.securityQuestion,
    required this.securityAnswer,
    required this.securityQuestion2,
    required this.securityAnswer2,
    required this.lockScheduleEnabled,
    required this.scheduleStartHour,
    required this.scheduleEndHour,
    required this.accelerometerEnabled,
    required this.wakeHour,
    required this.sleepHour,
  });

  UserSettings copyWith({
    String? userName,
    int? dailyLimitMinutes,
    int? cooldownMinutes,
    int? extraUnlockMinutes,
    int? maxUnlocksPerDay,
    List<String>? monitoredApps,
    String? securityQuestion,
    String? securityAnswer,
    String? securityQuestion2,
    String? securityAnswer2,
    bool? lockScheduleEnabled,
    int? scheduleStartHour,
    int? scheduleEndHour,
    bool? accelerometerEnabled,
    int? wakeHour,
    int? sleepHour,
  }) {
    return UserSettings(
      userName: userName ?? this.userName,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      extraUnlockMinutes: extraUnlockMinutes ?? this.extraUnlockMinutes,
      maxUnlocksPerDay: maxUnlocksPerDay ?? this.maxUnlocksPerDay,
      monitoredApps: monitoredApps ?? this.monitoredApps,
      securityQuestion: securityQuestion ?? this.securityQuestion,
      securityAnswer: securityAnswer ?? this.securityAnswer,
      securityQuestion2: securityQuestion2 ?? this.securityQuestion2,
      securityAnswer2: securityAnswer2 ?? this.securityAnswer2,
      lockScheduleEnabled: lockScheduleEnabled ?? this.lockScheduleEnabled,
      scheduleStartHour: scheduleStartHour ?? this.scheduleStartHour,
      scheduleEndHour: scheduleEndHour ?? this.scheduleEndHour,
      accelerometerEnabled: accelerometerEnabled ?? this.accelerometerEnabled,
      wakeHour: wakeHour ?? this.wakeHour,
      sleepHour: sleepHour ?? this.sleepHour,
    );
  }

  static UserSettings defaults() => const UserSettings(
        userName: '',
        dailyLimitMinutes: 60,
        cooldownMinutes: 30,
        extraUnlockMinutes: 15,
        maxUnlocksPerDay: 1,
        monitoredApps: [],
        securityQuestion: '',
        securityAnswer: '',
        securityQuestion2: '',
        securityAnswer2: '',
        lockScheduleEnabled: false,
        scheduleStartHour: 8,
        scheduleEndHour: 22,
        accelerometerEnabled: true,
        wakeHour: 7,
        sleepHour: 23,
      );
}
