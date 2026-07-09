import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color kBg = Color(0xFF0A0A0F);
const Color kSurface = Color(0xFF0D0D1A);
const Color kAccent = Color(0xFF00D4FF);
const Color kAccent2 = Color(0xFF0066FF);
const Color kText = Color(0xFFE0E0E0);
const Color kTextSub = Color(0xFF666699);
const Color kError = Color(0xFFFF3366);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (e) { debugPrint('Firebase skip'); }
  try { await FirebaseAuth.instance.signInAnonymously(); } catch (e) {}
  await Hive.initFlutter();
  await Hive.openBox('user_data');
  await Hive.openBox('sessions');
  await Hive.openBox('evolution');
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => RPGEngine()..loadFromHive()),
      ChangeNotifierProvider(create: (_) { final d = DashboardProvider(); d.init(); return d; }),
      ChangeNotifierProvider(create: (_) => TabataController()),
      ChangeNotifierProvider(create: (_) { final g = EvolutionGalleryProvider(); g.init(); return g; }),
      ChangeNotifierProvider(create: (_) { final s = SessionLogProvider(); s.init(); return s; }),
    ],
    child: const MyApp(),
  ));
}
