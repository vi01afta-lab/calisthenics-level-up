import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }
  
  await Hive.initFlutter();
  await Hive.openBox('user_data');
  await Hive.openBox('sessions');
  
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => RPGEngine()..loadFromHive()),
      ChangeNotifierProvider(create: (_) => DashboardProvider()..init()),
      ChangeNotifierProvider(create: (_) => TabataController()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        primaryColor: const Color(0xFF00D4FF),
      ),
      home: const AppShell(),
    );
  }
}

class RPGEngine extends ChangeNotifier {
  int level = 1;
  int xp = 0;
  final Box _box = Hive.box('user_data');

  void loadFromHive() {
    level = _box.get('level', defaultValue: 1);
    xp = _box.get('xp', defaultValue: 0);
    notifyListeners();
  }

  Future<void> registerSession(String exercise, int xpGain) async {
    xp += xpGain;
    if (xp >= 100) { level++; xp = 0; }
    _box.put('level', level);
    _box.put('xp', xp);
    
    // Offline-First: Guardar en Hive y sincronizar
    final sessionBox = Hive.box('sessions');
    final data = {'ex': exercise, 'xp': xpGain, 'ts': DateTime.now().toIso8601String()};
    await sessionBox.add(data);
    await syncPendingSessions();
    notifyListeners();
  }

  Future<void> syncPendingSessions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final box = Hive.box('sessions');
    final batch = FirebaseFirestore.instance.batch();
    
    for (var i = 0; i < box.length; i++) {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('sessions').doc();
      batch.set(docRef, box.getAt(i));
    }
    await batch.commit();
    await box.clear();
  }
}

class DashboardProvider extends ChangeNotifier {
  bool isLoading = true;
  Map<String, int> muscleGroupHits = {'Pecho': 0, 'Espalda': 0, 'Brazos': 0, 'Piernas': 0, 'Core': 0};

  void init() {
    final box = Hive.box('sessions');
    box.listenable().addListener(_updateStats);
    _updateStats();
    isLoading = false;
    notifyListeners();
  }

  void _updateStats() {
    final box = Hive.box('sessions');
    for (var s in box.values) {
      String group = _mapToGroup(s['ex']);
      muscleGroupHits[group] = (muscleGroupHits[group] ?? 0) + 1;
    }
    notifyListeners();
  }

  String _mapToGroup(String ex) => {'Push-ups': 'Pecho', 'Pull-ups': 'Espalda', 'Dips': 'Brazos', 'Squats': 'Piernas'}[ex] ?? 'Core';

  @override
  void dispose() {
    Hive.box('sessions').listenable().removeListener(_updateStats);
    super.dispose();
  }
}

class BarChartPainter extends CustomPainter {
  final Map<String, int> data;
  BarChartPainter(this.data);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF00D4FF);
    double x = 20;
    for (var val in data.values) {
      canvas.drawRect(Rect.fromLTWH(x, size.height - (val * 20), 40, val * 20.0), paint);
      x += 60;
    }
  }
  
  @override
  bool shouldRepaint(BarChartPainter oldDelegate) => oldDelegate.data != data;
}

class TabataController extends ChangeNotifier {
  int secondsLeft = 20;
  bool isActive = false;
  Timer? _timer;

  void start() {
    isActive = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft > 0) secondsLeft--;
      else t.cancel();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: const Center(child: Text("Calisthenics Level Up")));
}