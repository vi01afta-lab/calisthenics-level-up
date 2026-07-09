import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/rpg_engine.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (e) { debugPrint('Firebase: $e'); }
  try { await FirebaseAuth.instance.signInAnonymously(); } catch (e) {}
  await StorageService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => RPGEngine()..loadFromStorage(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calisthenics Level Up',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: kBg),
      home: const HomeScreen(),
    );
  }
}
