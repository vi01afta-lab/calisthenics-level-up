import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Service Locator para desacoplar lógica de UI
class ServiceLocator {
  static final ServiceLocator instance = ServiceLocator._internal();
  ServiceLocator._internal();
  EvolutionGalleryProvider? galleryProvider;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAuth.instance.signInAnonymously();
  await Hive.initFlutter();
  await Hive.openBox('user_data');
  await Hive.openBox('sessions');
  await Hive.openBox('evolution');

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => RPGEngine()..loadFromHive()),
      ChangeNotifierProvider(create: (_) => EvolutionGalleryProvider()..init()),
      ChangeNotifierProvider(create: (_) => SessionLogProvider()..init()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Registrar proveedores en el locator
    ServiceLocator.instance.galleryProvider = context.read<EvolutionGalleryProvider>();
    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0F)),
      home: const AppShell(),
    );
  }
}

class RPGEngine extends ChangeNotifier {
  int level = 1; int xp = 0; int totalSessions = 0;
  void loadFromHive() { 
    final box = Hive.box('user_data'); 
    level = box.get('level', defaultValue: 1); 
    xp = box.get('xp', defaultValue: 0); 
    notifyListeners(); 
  }
  void registerSession(int xpGained) {
    int oldLevel = level;
    xp += xpGained;
    if (xp >= level * 100) { level++; xp = 0; }
    totalSessions++;
    Hive.box('user_data').putAll({'level': level, 'xp': xp});
    notifyListeners();
    if (level > oldLevel) {
      ServiceLocator.instance.galleryProvider?.recordSnapshot(level, xp, totalSessions);
    }
  }
}

class EvolutionGalleryProvider extends ChangeNotifier {
  List<Map> entries = [];
  bool isLoading = true;
  void init() {
    final box = Hive.box('evolution');
    entries = box.values.toList().cast<Map>();
    isLoading = false;
    notifyListeners();
  }
  Future<void> recordSnapshot(int level, int xp, int total) async {
    await Hive.box('evolution').add({'date': DateTime.now().toString(), 'level': level});
    init();
  }
  @override
  void dispose() { super.dispose(); }
}

class SessionLogProvider extends ChangeNotifier {
  List<Map> sessions = [];
  void init() {
    sessions = Hive.box('sessions').values.toList().cast<Map>();
    notifyListeners();
  }
  void addSession(String ex, int reps) {
    Hive.box('sessions').add({'ex': ex, 'reps': reps, 'date': DateTime.now().toIso8601String()});
    init();
  }
  @override
  void dispose() { super.dispose(); }
}

class AppShell extends StatefulWidget { const AppShell({super.key}); @override State<AppShell> createState() => _AppShellState(); }
class _AppShellState extends State<AppShell> {
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: [
        Center(child: ElevatedButton(onPressed: () => context.read<RPGEngine>().registerSession(50), child: const Text("Entrenar"))),
        const Center(child: Text("Stats")),
      ]),
      bottomNavigationBar: BottomNavigationBar(currentIndex: _idx, onTap: (i) => setState(() => _idx = i), items: const [
        BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Entrena'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
      ]),
    );
  }
}