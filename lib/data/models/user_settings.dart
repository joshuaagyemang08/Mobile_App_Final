class UserSettings {
  final String userName;
  final int dailyLimitMinutes;
  final int cooldownMinutes;
  final int extraUnlockMinutes;
  final int maxUnlocksPerDay;
  final List<String> monitoredApps;
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
        lockScheduleEnabled: false,
        scheduleStartHour: 8,
        scheduleEndHour: 22,
        accelerometerEnabled: true,
        wakeHour: 7,
        sleepHour: 23,
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
      scheduleEndHour: _asInt(json['scheduleEndHour'], 22),
      accelerometerEnabled: _asBool(json['accelerometerEnabled'], true),
      wakeHour: _asInt(json['wakeHour'], 7),
      sleepHour: _asInt(json['sleepHour'], 23),
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
      'scheduleEndHour': scheduleEndHour,
      'accelerometerEnabled': accelerometerEnabled,
      'wakeHour': wakeHour,
      'sleepHour': sleepHour,
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
