import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

const kBg = Color(0xFF0A0A0F);
const kAccent = Color(0xFF00D4FF);
const kGold = Color(0xFFFFD700);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (e) {}
  try { await FirebaseAuth.instance.signInAnonymously(); } catch (e) {}
  await Hive.initFlutter();
  await Hive.openBox('muscles');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: MaterialApp(theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: kBg), home: const MuscleMapScreen()),
    );
  }
}

class DashboardProvider extends ChangeNotifier {
  final Box _box = Hive.box('muscles');
  Timer? _debounce;

  Future<void> updateMuscleCooldown(String id, DateTime expiry) async {
    final oldExpiry = _box.get(id);
    if (oldExpiry == expiry.toIso8601String()) return;

    _box.put(id, expiry.toIso8601String());
    notifyListeners();

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 2), () async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('muscles').doc(id).set({
          'cooldownExpiry': Timestamp.fromDate(expiry)
        });
      }
    });
  }
}

class TabataController extends ChangeNotifier {
  Timer? _timer;
  void start(Function onTick) => _timer = Timer.periodic(const Duration(seconds: 1), (_) => onTick());
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class MuscleMapScreen extends StatefulWidget {
  const MuscleMapScreen({super.key});
  @override
  State<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends State<MuscleMapScreen> {
  final TabataController _tabata = TabataController();

  @override
  void dispose() {
    _tabata.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text("Calisthenics Level Up")));
  }
}