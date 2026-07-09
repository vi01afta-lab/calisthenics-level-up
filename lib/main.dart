import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await Hive.openBox('user_stats');
  runApp(const MyApp());
}

class StatsRepository {
  final Box _box = Hive.box('user_stats');
  
  double get xp => _box.get('xp', defaultValue: 0.0);
  
  void updateXp(double newXp) {
    _box.put('xp', newXp);
    // Aquí iría la lógica de sincronización diferida con Firestore
  }
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
      home: const RPGDashboard(),
    );
  }
}

class RPGDashboard extends StatefulWidget {
  const RPGDashboard({super.key});
  @override
  State<RPGDashboard> createState() => _RPGDashboardState();
}

class _RPGDashboardState extends State<RPGDashboard> {
  late StreamSubscription<User?> _authSubscription;
  final StatsRepository _repo = StatsRepository();

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {});
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 60),
          ValueListenableBuilder(
            valueListenable: Hive.box('user_stats').listenable(),
            builder: (context, box, _) {
              return XPBar(currentXp: _repo.xp, maxXp: 1000);
            },
          ),
          const Expanded(child: TabataWidget()),
        ],
      ),
    );
  }
}

class XPBar extends StatelessWidget {
  final double currentXp, maxXp;
  const XPBar({super.key, required this.currentXp, required this.maxXp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text("${(currentXp / maxXp * 100).toInt()}%", style: const TextStyle(fontFamily: 'Orbitron', color: Color(0xFF00D4FF))),
          LinearProgressIndicator(value: currentXp / maxXp, backgroundColor: Colors.white10, color: const Color(0xFF00D4FF)),
        ],
      ),
    );
  }
}

class TabataWidget extends StatefulWidget {
  const TabataWidget({super.key});
  @override
  State<TabataWidget> createState() => _TabataWidgetState();
}

class _TabataWidgetState extends State<TabataWidget> {
  int _seconds = 20;
  Timer? _timer;
  bool _isActive = false;
  final StatsRepository _repo = StatsRepository();

  void _toggleTimer() {
    if (_isActive) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_seconds > 0) {
          setState(() => _seconds--);
        } else {
          _timer?.cancel();
          _repo.updateXp(_repo.xp + 10); // Sincronización diferida al finalizar
        }
      });
    }
    setState(() => _isActive = !_isActive);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("$_seconds", style: const TextStyle(fontFamily: 'Orbitron', fontSize: 80, color: Colors.white)),
        IconButton(
          icon: Icon(_isActive ? Icons.pause : Icons.play_arrow, size: 50, color: const Color(0xFF00D4FF)),
          onPressed: _toggleTimer,
        )
      ],
    );
  }
}