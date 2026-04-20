class UserSettings {
  final String userName;
  final int dailyLimitMinutes;
  final int cooldownMinutes;
  final int extraUnlockMinutes;
  final int maxUnlocksPerDay;
  final List<String> monitoredApps;
  final bool lockScheduleEnabled;
  final int scheduleStartHour;
  final int scheduleStartMinute;
  final int scheduleEndHour;
  final int scheduleEndMinute;
  final bool accelerometerEnabled;
  final int wakeHour;
  final int wakeMinute;
  final int sleepHour;
  final int sleepMinute;
  final bool notificationsEnabled;

  const UserSettings({
    required this.userName,
    required this.dailyLimitMinutes,
    required this.cooldownMinutes,
    required this.extraUnlockMinutes,
    required this.maxUnlocksPerDay,
    required this.monitoredApps,
    required this.lockScheduleEnabled,
    required this.scheduleStartHour,
    required this.scheduleStartMinute,
    required this.scheduleEndHour,
    required this.scheduleEndMinute,
    required this.accelerometerEnabled,
    required this.wakeHour,
    required this.wakeMinute,
    required this.sleepHour,
    required this.sleepMinute,
    required this.notificationsEnabled,
  });

  UserSettings copyWith({
    String? userName,
    int? dailyLimitMinutes,
    int? cooldownMinutes,
    int? extraUnlockMinutes,
    int? maxUnlocksPerDay,
    List<String>? monitoredApps,
    bool? lockScheduleEnabled,
    int? scheduleStartHour,
    int? scheduleStartMinute,
    int? scheduleEndHour,
    int? scheduleEndMinute,
    bool? accelerometerEnabled,
    int? wakeHour,
    int? wakeMinute,
    int? sleepHour,
    int? sleepMinute,
    bool? notificationsEnabled,
  }) {
    return UserSettings(
      userName: userName ?? this.userName,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      extraUnlockMinutes: extraUnlockMinutes ?? this.extraUnlockMinutes,
      maxUnlocksPerDay: maxUnlocksPerDay ?? this.maxUnlocksPerDay,
      monitoredApps: monitoredApps ?? this.monitoredApps,
      lockScheduleEnabled: lockScheduleEnabled ?? this.lockScheduleEnabled,
      scheduleStartHour: scheduleStartHour ?? this.scheduleStartHour,
      scheduleStartMinute: scheduleStartMinute ?? this.scheduleStartMinute,
      scheduleEndHour: scheduleEndHour ?? this.scheduleEndHour,
      scheduleEndMinute: scheduleEndMinute ?? this.scheduleEndMinute,
      accelerometerEnabled: accelerometerEnabled ?? this.accelerometerEnabled,
      wakeHour: wakeHour ?? this.wakeHour,
      wakeMinute: wakeMinute ?? this.wakeMinute,
      sleepHour: sleepHour ?? this.sleepHour,
      sleepMinute: sleepMinute ?? this.sleepMinute,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  static UserSettings defaults() => const UserSettings(
        userName: '',
        dailyLimitMinutes: 60,
        cooldownMinutes: 30,
        extraUnlockMinutes: 15,
        maxUnlocksPerDay: 1,
        monitoredApps: [],
        lockScheduleEnabled: false,
        scheduleStartHour: 8,
        scheduleStartMinute: 0,
        scheduleEndHour: 22,
        scheduleEndMinute: 0,
        accelerometerEnabled: true,
        wakeHour: 7,
        wakeMinute: 0,
        sleepHour: 23,
        sleepMinute: 0,
        notificationsEnabled: true,
      );

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    final monitoredApps = json['monitoredApps'];
    return UserSettings(
      userName: (json['userName'] ?? '').toString(),
      dailyLimitMinutes: _asInt(json['dailyLimitMinutes'], 60),
      cooldownMinutes: _asInt(json['cooldownMinutes'], 30),
      extraUnlockMinutes: _asInt(json['extraUnlockMinutes'], 15),
      maxUnlocksPerDay: _asInt(json['maxUnlocksPerDay'], 1),
      monitoredApps: monitoredApps is List
          ? monitoredApps.map((value) => value.toString()).toList()
          : <String>[],
      lockScheduleEnabled: _asBool(json['lockScheduleEnabled'], false),
      scheduleStartHour: _asInt(json['scheduleStartHour'], 8),
      scheduleStartMinute: _asInt(json['scheduleStartMinute'], 0),
      scheduleEndHour: _asInt(json['scheduleEndHour'], 22),
      scheduleEndMinute: _asInt(json['scheduleEndMinute'], 0),
      accelerometerEnabled: _asBool(json['accelerometerEnabled'], true),
      wakeHour: _asInt(json['wakeHour'], 7),
      wakeMinute: _asInt(json['wakeMinute'], 0),
      sleepHour: _asInt(json['sleepHour'], 23),
      sleepMinute: _asInt(json['sleepMinute'], 0),
      notificationsEnabled: _asBool(json['notificationsEnabled'], true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'dailyLimitMinutes': dailyLimitMinutes,
      'cooldownMinutes': cooldownMinutes,
      'extraUnlockMinutes': extraUnlockMinutes,
      'maxUnlocksPerDay': maxUnlocksPerDay,
      'monitoredApps': monitoredApps,
      'lockScheduleEnabled': lockScheduleEnabled,
      'scheduleStartHour': scheduleStartHour,
      'scheduleStartMinute': scheduleStartMinute,
      'scheduleEndHour': scheduleEndHour,
      'scheduleEndMinute': scheduleEndMinute,
      'accelerometerEnabled': accelerometerEnabled,
      'wakeHour': wakeHour,
      'wakeMinute': wakeMinute,
      'sleepHour': sleepHour,
      'sleepMinute': sleepMinute,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _asBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == 'true' || value == '1';
    return fallback;
  }
}
