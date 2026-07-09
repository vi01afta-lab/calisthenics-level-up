import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await Hive.openBox('rpg_data');
  await Hive.openBox('sync_queue');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0F)),
      home: const RPGDashboard(),
    );
  }
}

class SyncService {
  static Future<void> sync() async {
    final box = Hive.box('sync_queue');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || box.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final keys = box.keys.toList();
    
    for (var key in keys) {
      final data = box.get(key);
      final ref = FirebaseFirestore.instance.collection('users').doc(uid).collection('sessions').doc();
      batch.set(ref, {...data, 'userId': uid});
    }
    
    await batch.commit();
    await box.clear();
  }
}

class RPGDashboard extends StatefulWidget {
  const RPGDashboard({super.key});
  @override
  State<RPGDashboard> createState() => _RPGDashboardState();
}

class _RPGDashboardState extends State<RPGDashboard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) SyncService.sync();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: TabataWidget()));
}

class TabataWidget extends StatefulWidget {
  const TabataWidget({super.key});
  @override
  State<TabataWidget> createState() => _TabataWidgetState();
}

class _TabataWidgetState extends State<TabataWidget> {
  Timer? _timer;
  int _seconds = 20;

  void _saveSession() {
    final box = Hive.box('sync_queue');
    box.add({'duration': 20, 'timestamp': DateTime.now().toIso8601String()});
    SyncService.sync();
  }

  void _toggleTimer() {
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_seconds > 0) setState(() => _seconds--);
        else {
          t.cancel();
          _saveSession();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("$_seconds", style: const TextStyle(fontSize: 80)),
      IconButton(icon: const Icon(Icons.play_arrow), onPressed: _toggleTimer)
    ]);
  }
}