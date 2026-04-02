class AppUsageEntry {
  final int? id;
  final String date;
  final String packageName;
  final String appName;
  final int durationMinutes;

  const AppUsageEntry({
    this.id,
    required this.date,
    required this.packageName,
    required this.appName,
    required this.durationMinutes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'package_name': packageName,
        'app_name': appName,
        'duration_minutes': durationMinutes,
      };

  factory AppUsageEntry.fromMap(Map<String, dynamic> m) => AppUsageEntry(
        id: m['id'] as int?,
        date: m['date'] as String,
        packageName: m['package_name'] as String,
        appName: m['app_name'] as String,
        durationMinutes: m['duration_minutes'] as int,
      );
}

class DailyUsageSummary {
  final String date;
  final int totalMinutes;
  final List<AppUsageEntry> entries;

  const DailyUsageSummary({
    required this.date,
    required this.totalMinutes,
    required this.entries,
  });
}
