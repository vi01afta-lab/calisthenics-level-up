import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase Init Error: $e');
  }

  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint('Auth Error: $e');
  }

  await Hive.initFlutter();
  await Hive.openBox('rpg_data');
  
  runApp(const MyApp());
}

class RPGEngine extends ChangeNotifier {
  final Box _box = Hive.box('rpg_data');
  int get level => _box.get('level', defaultValue: 1);
  int get xp => _box.get('xp', defaultValue: 0);

  void registerSession(String exercise, int series, int reps) {
    int newXp = xp + (series * reps * 10);
    int newLevel = level;
    if (newXp >= newLevel * 100) {
      newLevel++;
      newXp = 0;
    }
    _box.put('level', newLevel);
    _box.put('xp', newXp);
    notifyListeners();
  }
}

class TabataController extends ChangeNotifier {
  Timer? _timer;
  bool isActive = false;

  void toggle() {
    isActive = !isActive;
    if (!isActive) _timer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => RPGEngine()),
      ChangeNotifierProvider(create: (_) => TabataController()),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final engine = context.watch<RPGEngine>();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Nivel: ${engine.level}', style: const TextStyle(fontSize: 24)),
            Text('XP: ${engine.xp}', style: const TextStyle(fontSize: 18)),
            ElevatedButton(
              onPressed: () => engine.registerSession('Push-ups', 3, 10),
              child: const Text('Entrenar'),
            )
          ],
        ),
      ),
    );
  }
}