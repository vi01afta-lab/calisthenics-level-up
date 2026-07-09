import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color kBg = Color(0xFF0A0A0F);
const Color kSurface = Color(0xFF0D0D1A);
const Color kAccent = Color(0xFF00D4FF);
const Color kAccent2 = Color(0xFF0066FF);
const Color kText = Color(0xFFE0E0E0);
const Color kTextSub = Color(0xFF666699);
const Color kError = Color(0xFFFF3366);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (e) { debugPrint('Firebase skip'); }
  try { await FirebaseAuth.instance.signInAnonymously(); } catch (e) {}
  await Hive.initFlutter();
  await Hive.openBox('user_data');
  await Hive.openBox('sessions');
  await Hive.openBox('evolution');
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => RPGEngine()..loadFromHive()),
      ChangeNotifierProvider(create: (_) { final d = DashboardProvider(); d.init(); return d; }),
      ChangeNotifierProvider(create: (_) => TabataController()),
      ChangeNotifierProvider(create: (_) { final g = EvolutionGalleryProvider(); g.init(); return g; }),
      ChangeNotifierProvider(create: (_) { final s = SessionLogProvider(); s.init(); return s; }),
    ],
    child: const MyApp(),
  ));
}

// ═══ ETAPA 1 — MOTOR RPG ═══

class RPGEngine extends ChangeNotifier {
  int level = 1, xp = 0, totalSessions = 0;
  Map<String, DateTime> cooldowns = {};
  int get requiredXP => (100 * pow(level, 1.5)).round();
  double get xpPercent => xp / requiredXP;

  void loadFromHive() {
    final box = Hive.box('user_data');
    level = box.get('level', defaultValue: 1);
    xp = box.get('xp', defaultValue: 0);
    totalSessions = box.get('totalSessions', defaultValue: 0);
    final cd = box.get('cooldowns', defaultValue: <String, dynamic>{});
    if (cd is Map) {
      cooldowns = {};
      cd.forEach((k, v) { if (v is String) cooldowns[k.toString()] = DateTime.parse(v); });
    }
    notifyListeners();
  }

  bool isOnCooldown(String ex) {
    final e = cooldowns[ex];
    return e != null && DateTime.now().isBefore(e);
  }

  Duration remainingCooldown(String ex) {
    final e = cooldowns[ex];
    if (e == null) return Duration.zero;
    final r = e.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  Future<void> registerSession(String exercise, int series, int reps) async {
    final xpGained = series * reps * 2;
    final cdH = ((series * reps * 0.5) / 2.0).clamp(12.0, 72.0);
    xp += xpGained;
    totalSessions++;
    cooldowns[exercise] = DateTime.now().add(Duration(hours: cdH.round()));
    while (xp >= requiredXP) { xp -= requiredXP; level++; }
    final cdMap = <String, String>{};
    cooldowns.forEach((k, v) => cdMap[k] = v.toIso8601String());
    await Hive.box('user_data').putAll({'level': level, 'xp': xp, 'totalSessions': totalSessions, 'cooldowns': cdMap});
    notifyListeners();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid)
            .set({'level': level, 'xp': xp, 'totalSessions': totalSessions}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> syncPendingSessions() async {}
}
