import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color bgColor = Color(0xFF0A0A0F);
const Color accentColor = Color(0xFF00D4FF);
const TextStyle orbitron = TextStyle(fontFamily: 'Orbitron', color: Colors.white);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('evolution');
  await Hive.openBox('sessions');

  try { await Firebase.initializeApp(); } catch (e) {}
  try { await FirebaseAuth.instance.signInAnonymously(); } catch (e) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EvolutionGalleryProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class EvolutionGalleryProvider extends ChangeNotifier {
  final Box _box = Hive.box('evolution');
  StreamSubscription? _syncSub;

  Future<void> saveEntry(Map<String, dynamic> entry) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    // Offline-First: Guardar en Hive
    await _box.add(entry);
    notifyListeners();

    // Sincronización a Firestore
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('evolution').add(entry);
    } catch (e) { debugPrint("Sync error: $e"); }
  }

  Future<List<Map<String, dynamic>>> getEntries() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    
    // Free Tier: Limit 20
    final snapshot = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('evolution')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();
        
    return snapshot.docs.map((d) => d.data()).toList();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: bgColor),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text("CALISTHENICS LEVEL UP", style: orbitron)),
    );
  }
}