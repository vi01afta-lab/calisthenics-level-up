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
    await Hive.initFlutter();
    await Hive.openBox('user_data');
    await Hive.openBox('sessions');
  } catch (e) {
    debugPrint("Error crítico de inicialización: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RPGEngine()..loadFromHive()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0F)),
        home: const AppShell(),
      ),
    );
  }
}

class RPGEngine extends ChangeNotifier {
  int level = 1;
  int xp = 0;
  
  void loadFromHive() {
    var box = Hive.box('user_data');
    level = box.get('level', defaultValue: 1);
    xp = box.get('xp', defaultValue: 0);
    notifyListeners();
  }

  Future<void> registerSession(String exercise, int xpGain) async {
    xp += xpGain;
    if (xp >= 100) { level++; xp = 0; }
    
    final box = Hive.box('user_data');
    await box.putAll({'level': level, 'xp': xp});
    await Hive.box('sessions').add({'exercise': exercise, 'ts': DateTime.now().toIso8601String()});
    notifyListeners();
  }
}

class TabataController extends ChangeNotifier {
  int secondsLeft = 20;
  Timer? _timer;
  bool isActive = false;

  void start() {
    isActive = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft > 0) {
        secondsLeft--;
        notifyListeners();
      } else {
        t.cancel();
        isActive = false;
        notifyListeners();
      }
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Nivel: ${context.watch<RPGEngine>().level}"),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TabataView())),
              child: const Text("Iniciar Tabata"),
            )
          ],
        ),
      ),
    );
  }
}

class TabataView extends StatelessWidget {
  const TabataView({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TabataController(),
      builder: (context, _) => Scaffold(
        body: Center(
          child: Text("Tiempo: ${context.watch<TabataController>().secondsLeft}"),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.read<TabataController>().start(),
          child: const Icon(Icons.play_arrow),
        ),
      ),
    );
  }
}