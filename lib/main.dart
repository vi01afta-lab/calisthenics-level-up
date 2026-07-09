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

class RPGDashboard extends StatelessWidget {
  const RPGDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return ValueListenableBuilder(
            valueListenable: Hive.box('user_stats').listenable(),
            builder: (context, Box box, _) {
              return SafeArea(
                child: Column(
                  children: [
                    Text("PLAYER: ${snapshot.data?.uid ?? 'GUEST'}", 
                      style: const TextStyle(fontFamily: 'Rajdhani', color: Color(0xFF00D4FF))),
                    XPBar(currentXp: box.get('xp', defaultValue: 0.0)),
                    const TabataWidget(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class XPBar extends StatelessWidget {
  final double currentXp;
  const XPBar({super.key, required this.currentXp});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      width: double.infinity,
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF00D4FF))),
      child: LinearProgressIndicator(
        value: (currentXp / 1000).clamp(0.0, 1.0), 
        backgroundColor: Colors.black, 
        color: const Color(0xFF00D4FF)
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
  int seconds = 20;
  Timer? _timer;

  void toggleTimer() {
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          if (seconds > 0) {
            seconds--;
          } else {
            _timer?.cancel();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("$seconds", style: const TextStyle(fontFamily: 'Orbitron', fontSize: 48, color: Colors.white)),
        ElevatedButton(onPressed: toggleTimer, child: const Text("START/PAUSE")),
      ],
    );
  }
}