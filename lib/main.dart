import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

const Color kBg = Color(0xFF0A0A0F);
const Color kPanel = Color(0xFF12121A);
const Color kAccent = Color(0xFF00D4FF);
const Color kTextSub = Color(0xFF888899);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {}
  
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {}

  await Hive.initFlutter();
  await Hive.openBox('user_stats');
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => RPGEngine()),
        ChangeNotifierProvider(create: (_) => TabataController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: kBg),
      home: const DashboardScreen(),
    );
  }
}

class DashboardProvider extends ChangeNotifier {
  final Box _box = Hive.box('user_stats');
  Timer? _syncTimer;
  int _xpBuffer = 0;

  int get xp => _box.get('xp', defaultValue: 0);
  int get level => (xp / 100).floor();

  void addXp(int amount) {
    _box.put('xp', xp + amount);
    _xpBuffer += amount;
    notifyListeners();
    
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 5), _syncToFirestore);
  }

  Future<void> _syncToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _xpBuffer > 0) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'xp': xp, 'lastUpdated': FieldValue.serverTimestamp()},
        SetOptions(merge: true)
      );
      _xpBuffer = 0;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

class TabataController extends ChangeNotifier {
  bool _isActive = false;
  final List<StreamSubscription> _subs = [];

  bool get isActive => _isActive;
  
  void toggle() { _isActive = !_isActive; notifyListeners(); }

  @override
  void dispose() {
    for (var sub in _subs) { sub.cancel(); }
    super.dispose();
  }
}

class RPGEngine extends ChangeNotifier {
  final Map<String, DateTime> _cooldowns = {};
  void registerSession(String primary) {
    _cooldowns[primary] = DateTime.now().add(const Duration(hours: 24));
    notifyListeners();
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("NIVEL ${dash.level}", style: GoogleFonts.orbitron(fontSize: 32, color: kAccent)),
            ElevatedButton(onPressed: () => dash.addXp(10), child: const Text("Entrenar (+10 XP)")),
          ],
        ),
      ),
    );
  }
}