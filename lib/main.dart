import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('user_stats');
  await Firebase.initializeApp();
  runApp(const CalisthenicsApp());
}

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Box _box = Hive.box('user_stats');

  Future<void> updateStats(int level, double xp) async {
    _box.putAll({'level': level, 'xp': xp});
    try {
      await _db.collection('users').doc('current_user_id').set({
        'level': level,
        'xp': xp,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Offline mode: Data cached locally.");
    }
  }
}

class DashboardProvider extends ChangeNotifier {
  final UserRepository _repo = UserRepository();
  int level = 1;
  double xp = 0.0;

  DashboardProvider() {
    final box = Hive.box('user_stats');
    level = box.get('level', defaultValue: 1);
    xp = box.get('xp', defaultValue: 0.0);
  }

  void addXp(double amount) {
    xp += amount;
    if (xp >= 100) { level++; xp = 0; }
    _repo.updateStats(level, xp);
    notifyListeners();
  }
}

class CalisthenicsApp extends StatelessWidget {
  const CalisthenicsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0F)),
        home: const RPGDashboard(),
      ),
    );
  }
}

class RPGDashboard extends StatelessWidget {
  const RPGDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("LEVEL ${provider.level}", style: const TextStyle(fontSize: 32)),
            LinearProgressIndicator(value: provider.xp / 100),
            ElevatedButton(onPressed: () => provider.addXp(10), child: const Text("Entrenar")),
          ],
        ),
      ),
    );
  }
}