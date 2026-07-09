import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (e) {}
  try { await FirebaseAuth.instance.signInAnonymously(); } catch (e) {}
  
  await Hive.initFlutter();
  await Hive.openBox('user_data');
  await Hive.openBox('sessions');
  await Hive.openBox('evolution');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RPGEngine()),
        ChangeNotifierProvider(create: (_) => EvolutionGalleryProvider()..init()),
        ChangeNotifierProvider(create: (_) => SessionLogProvider()..init()),
      ],
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0F)),
        home: const AppShell(),
      ),
    );
  }
}

class RPGEngine extends ChangeNotifier {
  int level = 1;
  int xp = 0;
  int requiredXP = 100;

  void registerSession(String exercise, int series, int reps, BuildContext context) {
    int xpGained = (series * reps * 10);
    xp += xpGained;
    if (xp >= requiredXP) {
      level++;
      xp -= requiredXP;
      requiredXP = (requiredXP * 1.2).toInt();
      context.read<EvolutionGalleryProvider>().recordSnapshot(level, xp);
    }
    context.read<SessionLogProvider>().addSession(exercise, series, reps, xpGained);
    notifyListeners();
  }
}

class EvolutionGalleryProvider extends ChangeNotifier {
  List<Map> entries = [];
  
  Future<void> init() async {
    entries = Hive.box('evolution').values.cast<Map>().toList();
    notifyListeners();
  }

  Future<void> recordSnapshot(int level, int xp) async {
    final data = {'date': DateTime.now().toIso8601String(), 'level': level, 'xp': xp, 'isSynced': false};
    await Hive.box('evolution').add(data);
    entries.add(data);
    _sync();
    notifyListeners();
  }

  Future<void> _sync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final box = Hive.box('evolution');
    for (int i = 0; i < box.length; i++) {
      var entry = Map.from(box.getAt(i));
      if (entry['isSynced'] == false) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('evolution').add(entry);
        entry['isSynced'] = true;
        await box.putAt(i, entry);
      }
    }
  }
}

class SessionLogProvider extends ChangeNotifier {
  List<Map> sessions = [];
  
  Future<void> init() async {
    sessions = Hive.box('sessions').values.cast<Map>().toList().reversed.toList();
    notifyListeners();
  }

  Future<void> addSession(String exercise, int series, int reps, int xp) async {
    final data = {'exercise': exercise, 'xp': xp, 'date': DateTime.now().toIso8601String(), 'isSynced': false};
    await Hive.box('sessions').add(data);
    sessions.insert(0, data);
    _sync();
    notifyListeners();
  }

  Future<void> _sync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final box = Hive.box('sessions');
    for (int i = 0; i < box.length; i++) {
      var entry = Map.from(box.getAt(i));
      if (entry['isSynced'] == false) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('sessions').add(entry);
        entry['isSynced'] = true;
        await box.putAt(i, entry);
      }
    }
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _idx = 0;
  final List<Widget> _screens = [const HomeScreen(), const TabataScreen(), const SessionHistoryScreen()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'ENTRENA'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'TABATA'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'HISTORIAL'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final rpg = context.watch<RPGEngine>();
    return Center(child: ElevatedButton(onPressed: () => rpg.registerSession("Flexiones", 3, 10, context), child: Text("Nivel ${rpg.level}")));
  }
}

class TabataScreen extends StatefulWidget {
  const TabataScreen({super.key});
  @override
  State<TabataScreen> createState() => _TabataScreenState();
}

class _TabataScreenState extends State<TabataScreen> {
  Timer? _timer;
  int seconds = 20;
  void start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds > 0) setState(() => seconds--);
      else t.cancel();
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("$seconds"), IconButton(icon: const Icon(Icons.play_arrow), onPressed: start)]));
}

class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final logs = context.watch<SessionLogProvider>();
    return ListView.builder(itemCount: logs.sessions.length, itemBuilder: (c, i) => ListTile(title: Text(logs.sessions[i]['exercise'])));
  }
}