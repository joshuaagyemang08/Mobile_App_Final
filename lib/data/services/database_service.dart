import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/app_usage_model.dart';
import '../../core/utils/time_utils.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'focuslock.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE usage_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            package_name TEXT NOT NULL,
            app_name TEXT NOT NULL,
            duration_minutes INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_date ON usage_history(date)');
      },
    );
  }

  /// Upsert today's entry for a package (insert or update)
  Future<void> upsertUsage(String packageName, String appName, int minutes) async {
    final database = await db;
    final today = TimeUtils.todayKey();

    final existing = await database.query(
      'usage_history',
      where: 'date = ? AND package_name = ?',
      whereArgs: [today, packageName],
    );

    if (existing.isEmpty) {
      await database.insert('usage_history', {
        'date': today,
        'package_name': packageName,
        'app_name': appName,
        'duration_minutes': minutes,
      });
    } else {
      await database.update(
        'usage_history',
        {'duration_minutes': minutes},
        where: 'date = ? AND package_name = ?',
        whereArgs: [today, packageName],
      );
    }
  }

  Future<List<AppUsageEntry>> getUsageForDate(String date) async {
    final database = await db;
    final maps = await database.query(
      'usage_history',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'duration_minutes DESC',
    );
    return maps.map(AppUsageEntry.fromMap).toList();
  }

  Future<List<DailyUsageSummary>> getLast7Days() async {
    final summaries = <DailyUsageSummary>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final entries = await getUsageForDate(key);
      final total = entries.fold<int>(0, (sum, entry) => sum + entry.durationMinutes);
      summaries.add(DailyUsageSummary(date: key, totalMinutes: total, entries: entries));
    }
    return summaries;
  }

  Future<int> getTodayTotalMinutes() async {
    final entries = await getUsageForDate(TimeUtils.todayKey());
    return entries.fold<int>(0, (sum, entry) => sum + entry.durationMinutes);
  }

  Future<void> clearUsageHistory() async {
    final database = await db;
    await database.delete('usage_history');
  }
}
