import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/muscle_data.dart';
import '../core/constants.dart';
import '../services/storage_service.dart';

class RPGEngine extends ChangeNotifier {
  int level = 1, xp = 0, totalSessions = 0;
  final List<MuscleData> muscles = MuscleData.defaultList();

  int get requiredXP => (100 * pow(level, 1.5)).round();
  double get xpPercent => xp / requiredXP;
  double get mpValue {
    final l = muscles.where((m) => !m.enCooldown).length;
    return l / muscles.length;
  }

  String get rank {
    if (level >= 50) return 'SSS';
    if (level >= 41) return 'S';
    if (level >= 31) return 'A';
    if (level >= 21) return 'B';
    if (level >= 11) return 'C';
    if (level >= 5) return 'D';
    return 'E';
  }

  Color get rankColor {
    switch (rank) {
      case 'SSS': return const Color(0xFFFF0000);
      case 'S': return const Color(0xFFFF6B00);
      case 'A': return kAccent2;
      case 'B': return kAccent;
      case 'C': return kGold;
      case 'D': return const Color(0xFFC0C0C0);
      default: return const Color(0xFFCD7F32);
    }
  }

  List<MuscleData> get musculosFrontales =>
      muscles.where((m) => m.esFrontal).toList();
  List<MuscleData> get musculosPosteriores =>
      muscles.where((m) => !m.esFrontal).toList();

  void loadFromStorage() {
    try {
      level = StorageService.level;
      xp = StorageService.xp;
      totalSessions = StorageService.totalSessions;
      for (final m in muscles) {
        final s = StorageService.getCooldown(m.id);
        if (s != null) m.cooldownExpiry = DateTime.tryParse(s);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> registerSession(String muscleId, int series, int reps) async {
    final list = muscles.where((x) => x.id == muscleId).toList();
    if (list.isEmpty || list.first.enCooldown) return;
    final m = list.first;
    final xpGained = series * reps * 2;
    final cdH = ((series * reps * 0.5) / 2.0).clamp(12.0, 72.0);
    xp += xpGained;
    totalSessions++;
    m.cooldownExpiry = DateTime.now().add(Duration(hours: cdH.round()));
    while (xp >= requiredXP) {
      xp -= requiredXP;
      level++;
    }
    try {
      await StorageService.saveAll(level, xp, totalSessions, m.id, m.cooldownExpiry!);
    } catch (_) {}
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'level': level, 'xp': xp, 'totalSessions': totalSessions},
                SetOptions(merge: true));
      }
    } catch (_) {}
    notifyListeners();
  }
}
