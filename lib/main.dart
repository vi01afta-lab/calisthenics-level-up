import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAuth.instance.signInAnonymously();
  await Hive.initFlutter();
  await Hive.openBox('user_data');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RPGEngine()..loadFromHive(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0F)),
        home: const HomeScreen(),
      ),
    );
  }
}

class RPGEngine extends ChangeNotifier {
  int level = 1;
  int xp = 0;
  Map<String, DateTime> cooldowns = {};
  Timer? _saveTimer;

  int get requiredXP => (100 * pow(level, 1.5)).toInt();
  double get xpPercent => (xp / requiredXP).clamp(0.0, 1.0);

  void loadFromHive() {
    var box = Hive.box('user_data');
    level = box.get('level', defaultValue: 1);
    xp = box.get('xp', defaultValue: 0);
    final savedCooldowns = box.get('cooldowns', defaultValue: {});
    cooldowns = (savedCooldowns as Map).map((k, v) => MapEntry(k, DateTime.fromMillisecondsSinceEpoch(v)));
    notifyListeners();
  }

  void registerSession(String exercise, int series, int reps) {
    xp += (series * reps * 2);
    while (xp >= requiredXP) { xp -= requiredXP; level++; }
    cooldowns[exercise] = DateTime.now().add(const Duration(hours: 12));
    
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 3), _persist);
    notifyListeners();
  }

  void _persist() {
    var box = Hive.box('user_data');
    box.put('level', level);
    box.put('xp', xp);
    box.put('cooldowns', cooldowns.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch)));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: Column(children: [
      const Padding(padding: EdgeInsets.all(20), child: XPBar()),
      Expanded(child: ListView(children: ['Push-ups', 'Pull-ups', 'Dips'].map((e) => ExerciseTile(name: e)).toList()))
    ])));
  }
}

class XPBar extends StatelessWidget {
  const XPBar({super.key});
  @override
  Widget build(BuildContext context) {
    final engine = context.watch<RPGEngine>();
    return Column(children: [
      Text("NIVEL ${engine.level}", style: const TextStyle(color: Color(0xFF00D4FF))),
      LinearProgressIndicator(value: engine.xpPercent),
    ]);
  }
}

class ExerciseTile extends StatelessWidget {
  final String name;
  const ExerciseTile({super.key, required this.name});
  @override
  Widget build(BuildContext context) {
    final engine = context.watch<RPGEngine>();
    final onCooldown = engine.cooldowns[name]?.isAfter(DateTime.now()) ?? false;
    return ListTile(title: Text(name), trailing: onCooldown ? const Icon(Icons.lock) : IconButton(icon: const Icon(Icons.add), onPressed: () => engine.registerSession(name, 3, 10)));
  }
}