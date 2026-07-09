import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const _boxName = 'user_data';

  static Box get _box => Hive.box(_boxName);

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static int get level => _box.get('level', defaultValue: 1);
  static int get xp => _box.get('xp', defaultValue: 0);
  static int get totalSessions => _box.get('totalSessions', defaultValue: 0);

  static Future<void> saveStats(int level, int xp, int totalSessions) async {
    await _box.putAll({
      'level': level,
      'xp': xp,
      'totalSessions': totalSessions,
    });
  }

  static String? getCooldown(String muscleId) => _box.get('cd_$muscleId');

  static Future<void> saveCooldown(String muscleId, DateTime expiry) async {
    await _box.put('cd_$muscleId', expiry.toIso8601String());
  }

  static Future<void> saveAll(
      int level, int xp, int totalSessions, String muscleId, DateTime expiry) async {
    await _box.putAll({
      'level': level,
      'xp': xp,
      'totalSessions': totalSessions,
      'cd_$muscleId': expiry.toIso8601String(),
    });
  }
}
