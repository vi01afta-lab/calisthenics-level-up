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

// ═══ ETAPA 1 — MOTOR RPG ═══

class RPGEngine extends ChangeNotifier {
  int level = 1, xp = 0, totalSessions = 0;
  Map<String, DateTime> cooldowns = {};
  int get requiredXP => (100 * pow(level, 1.5)).round();
  double get xpPercent => xp / requiredXP;

  void loadFromHive() {
    final box = Hive.box('user_data');
    level = box.get('level', defaultValue: 1);
    xp = box.get('xp', defaultValue: 0);
    totalSessions = box.get('totalSessions', defaultValue: 0);
    final cd = box.get('cooldowns', defaultValue: <String, dynamic>{});
    if (cd is Map) {
      cooldowns = {};
      cd.forEach((k, v) { if (v is String) cooldowns[k.toString()] = DateTime.parse(v); });
    }
    notifyListeners();
  }

  bool isOnCooldown(String ex) {
    final e = cooldowns[ex];
    return e != null && DateTime.now().isBefore(e);
  }

  Duration remainingCooldown(String ex) {
    final e = cooldowns[ex];
    if (e == null) return Duration.zero;
    final r = e.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  Future<void> registerSession(String exercise, int series, int reps) async {
    final xpGained = series * reps * 2;
    final cdH = ((series * reps * 0.5) / 2.0).clamp(12.0, 72.0);
    xp += xpGained;
    totalSessions++;
    cooldowns[exercise] = DateTime.now().add(Duration(hours: cdH.round()));
    while (xp >= requiredXP) { xp -= requiredXP; level++; }
    final cdMap = <String, String>{};
    cooldowns.forEach((k, v) => cdMap[k] = v.toIso8601String());
    await Hive.box('user_data').putAll({'level': level, 'xp': xp, 'totalSessions': totalSessions, 'cooldowns': cdMap});
    notifyListeners();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid)
            .set({'level': level, 'xp': xp, 'totalSessions': totalSessions}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> syncPendingSessions() async {}
}

class MuscleMapPainter extends CustomPainter {
  final Set<String> active;
  MuscleMapPainter(this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final bp = Paint()..style = PaintingStyle.stroke..color = kAccent.withOpacity(0.3)..strokeWidth = 1.5;
    final groups = {
      'pecho': Rect.fromLTWH(size.width * .3, size.height * .18, size.width * .4, size.height * .1),
      'espalda': Rect.fromLTWH(size.width * .25, size.height * .2, size.width * .5, size.height * .12),
      'hombros': Rect.fromLTWH(size.width * .15, size.height * .14, size.width * .15, size.height * .09),
      'brazos': Rect.fromLTWH(size.width * .08, size.height * .25, size.width * .12, size.height * .2),
      'core': Rect.fromLTWH(size.width * .3, size.height * .3, size.width * .4, size.height * .14),
      'piernas': Rect.fromLTWH(size.width * .25, size.height * .5, size.width * .5, size.height * .35),
    };
    p.color = kSurface;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .2, 0, size.width * .6, size.height), const Radius.circular(20)), p);
    groups.forEach((n, r) {
      p.color = active.contains(n) ? kAccent.withOpacity(0.7) : const Color(0xFF1A1A2E);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), p);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), bp);
    });
    p.color = const Color(0xFF1A1A2E);
    canvas.drawCircle(Offset(size.width * .5, size.height * .07), size.width * .08, p);
    canvas.drawCircle(Offset(size.width * .5, size.height * .07), size.width * .08, bp);
  }

  @override bool shouldRepaint(MuscleMapPainter o) => o.active != active;
}

class XPBar extends StatelessWidget {
  const XPBar({super.key});
  @override
  Widget build(BuildContext context) {
    final e = context.watch<RPGEngine>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('NIVEL ${e.level}', style: const TextStyle(color: kAccent, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          Text('${e.xp} / ${e.requiredXP} XP', style: const TextStyle(color: kTextSub, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: e.xpPercent.clamp(0.0, 1.0), minHeight: 8,
            backgroundColor: const Color(0xFF1A1A2E),
            valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
          ),
        ).animate().fadeIn(duration: 500.ms),
      ]),
    );
  }
}

class CooldownCard extends StatefulWidget {
  const CooldownCard({super.key});
  @override State<CooldownCard> createState() => _CCState();
}
class _CCState extends State<CooldownCard> {
  Timer? _t;
  @override void initState() { super.initState(); _t = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); }); }
  @override void dispose() { _t?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final e = context.watch<RPGEngine>();
    final active = e.cooldowns.entries.where((x) => e.isOnCooldown(x.key)).toList();
    if (active.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 20), SizedBox(width: 8), Text('LISTO PARA ENTRENAR', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
      );
    }
    final entry = active.first; final rem = e.remainingCooldown(entry.key);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kError.withOpacity(0.5))),
      child: Row(children: [
        const Icon(Icons.timer, color: kError, size: 20), const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.key.toUpperCase(), style: const TextStyle(color: kError, fontWeight: FontWeight.bold, fontSize: 12)),
          Text('${rem.inHours}h ${rem.inMinutes % 60}m ${rem.inSeconds % 60}s', style: const TextStyle(color: kText, fontFamily: 'monospace')),
        ]),
      ]),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HSState();
}
class _HSState extends State<HomeScreen> {
  final exercises = ['Push-ups', 'Pull-ups', 'Dips', 'Squats', 'Planks'];
  final muscleMap = {'Push-ups': 'pecho', 'Pull-ups': 'espalda', 'Dips': 'brazos', 'Squats': 'piernas', 'Planks': 'core'};

  void _showDialog(BuildContext ctx, String ex) {
    int s = 3, r = 10;
    showDialog(context: ctx, builder: (c) => StatefulBuilder(builder: (c, ss) => AlertDialog(
      backgroundColor: kSurface,
      title: Text(ex, style: const TextStyle(color: kAccent)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Series: $s', style: const TextStyle(color: kText)),
        Slider(value: s.toDouble(), min: 1, max: 10, divisions: 9, activeColor: kAccent, onChanged: (v) => ss(() => s = v.round())),
        Text('Reps: $r', style: const TextStyle(color: kText)),
        Slider(value: r.toDouble(), min: 1, max: 30, divisions: 29, activeColor: kAccent, onChanged: (v) => ss(() => r = v.round())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCELAR', style: TextStyle(color: kTextSub))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kAccent),
          onPressed: () async {
            Navigator.pop(c);
            final engine = context.read<RPGEngine>();
            final sessions = context.read<SessionLogProvider>();
            final gallery = context.read<EvolutionGalleryProvider>();
            final oldLevel = engine.level;
            final xpGained = s * r * 2;
            await engine.registerSession(ex, s, r);
            await sessions.addSession(ex, s, r, xpGained);
            if (engine.level > oldLevel) await gallery.recordSnapshot(engine.level, engine.xp, engine.totalSessions);
          },
          child: const Text('REGISTRAR', style: TextStyle(color: Colors.black)),
        ),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final e = context.watch<RPGEngine>();
    final am = e.cooldowns.entries.where((x) => e.isOnCooldown(x.key)).map((x) => muscleMap[x.key] ?? '').toSet();
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        const XPBar(), const SizedBox(height: 16),
        SizedBox(height: 300, child: CustomPaint(painter: MuscleMapPainter(am), size: const Size(200, 300))),
        const SizedBox(height: 16),
        ...exercises.map((ex) {
          final onCd = e.isOnCooldown(ex);
          final rem = e.remainingCooldown(ex);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(ex, style: const TextStyle(color: kText, fontSize: 16))),
              onCd
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: kError.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: kError.withOpacity(0.5))),
                    child: Text('${rem.inHours}h ${rem.inMinutes % 60}m', style: const TextStyle(color: kError, fontSize: 12, fontFamily: 'monospace')))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kAccent),
                    onPressed: () => _showDialog(context, ex),
                    child: const Text('REGISTRAR', style: TextStyle(color: Colors.black, fontSize: 12))),
            ]),
          );
        }),
        const SizedBox(height: 16), const CooldownCard(),
      ]))),
    );
  }
}

// ═══ ETAPA 2 — DASHBOARD + TABATA ═══

class DashboardProvider extends ChangeNotifier {
  bool isLoading = true;
  List<Map<String, dynamic>> recentSessions = [];
  Map<String, int> muscleGroupHits = {};
  int totalSessionsThisWeek = 0;
  double avgXPPerSession = 0.0;
  final _em = {'Push-ups': 'pecho', 'Pull-ups': 'espalda', 'Dips': 'brazos', 'Squats': 'piernas', 'Planks': 'core'};

  Future<void> init() async {
    final box = Hive.box('sessions');
    final all = box.values.toList();
    recentSessions = all.reversed.take(20).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    muscleGroupHits = {};
    int totalXP = 0;
    totalSessionsThisWeek = 0;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    for (final s in recentSessions) {
      final m = _em[s['exercise'] ?? ''] ?? 'core';
      muscleGroupHits[m] = (muscleGroupHits[m] ?? 0) + 1;
      totalXP += (s['xpGained'] as int? ?? 0);
      final d = DateTime.tryParse(s['date'] ?? '');
      if (d != null && d.isAfter(weekAgo)) totalSessionsThisWeek++;
    }
    avgXPPerSession = recentSessions.isEmpty ? 0 : totalXP / recentSessions.length;
    isLoading = false;
    notifyListeners();
  }
}

class BarChartPainter extends CustomPainter {
  final Map<String, int> data;
  BarChartPainter(this.data);
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.values.every((v) => v == 0)) {
      final tp = TextPainter(text: const TextSpan(text: 'SIN DATOS', style: TextStyle(color: kTextSub, fontSize: 14)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }
    final p = Paint()..style = PaintingStyle.fill;
    final maxV = data.values.reduce((a, b) => a > b ? a : b).toDouble();
    final keys = data.keys.toList();
    final bw = size.width / (keys.length * 2);
    for (int i = 0; i < keys.length; i++) {
      final v = data[keys[i]] ?? 0;
      final bh = maxV > 0 ? (v / maxV) * (size.height - 30) : 0.0;
      final x = i * bw * 2 + bw / 2;
      p.color = kAccent;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - 30 - bh, bw, bh), const Radius.circular(4)), p);
      final tp = TextPainter(text: TextSpan(text: keys[i].substring(0, 3), style: const TextStyle(color: kTextSub, fontSize: 9)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x + (bw - tp.width) / 2, size.height - 24));
    }
  }
  @override bool shouldRepaint(BarChartPainter o) => o.data != data;
}

Widget _statCard(String label, String value) => Expanded(child: Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)),
  child: Column(children: [
    Text(value, style: const TextStyle(color: kAccent, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
    Text(label, style: const TextStyle(color: kTextSub, fontSize: 10)),
  ]),
));

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DSState();
}
class _DSState extends State<DashboardScreen> {
  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DashboardProvider>().init()); }
  @override
  Widget build(BuildContext context) {
    final d = context.watch<DashboardProvider>();
    return Scaffold(backgroundColor: kBg, body: SafeArea(child: d.isLoading
      ? const Center(child: CircularProgressIndicator(color: kAccent))
      : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ESTADISTICAS RPG', style: TextStyle(color: kAccent, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [_statCard('SEMANA', '${d.totalSessionsThisWeek}'), const SizedBox(width: 8), _statCard('XP PROM', d.avgXPPerSession.toStringAsFixed(0)), const SizedBox(width: 8), _statCard('TOTAL', '${d.recentSessions.length}')]),
          const SizedBox(height: 16),
          Container(height: 150, decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(12), child: CustomPaint(painter: BarChartPainter(d.muscleGroupHits), size: Size.infinite)),
          const SizedBox(height: 16),
          if (d.recentSessions.isEmpty) const Center(child: Text('SIN HISTORIAL. COMIENZA A ENTRENAR!', style: TextStyle(color: kTextSub)))
          else ...d.recentSessions.take(5).map((s) => Card(color: kSurface, margin: const EdgeInsets.only(bottom: 4), child: ListTile(title: Text(s['exercise'] ?? '', style: const TextStyle(color: kText)), trailing: Text('+${s['xpGained']} XP', style: const TextStyle(color: kAccent))))),
        ]))));
  }
}

class TabataController extends ChangeNotifier {
  int workSeconds = 20, restSeconds = 10, totalRounds = 8, currentRound = 1;
  late int secondsLeft = workSeconds;
  bool isWorking = true, isActive = false, isFinished = false;
  Timer? _timer;

  void start() { if (isActive || isFinished) return; isActive = true; _timer = Timer.periodic(const Duration(seconds: 1), _tick); notifyListeners(); }
  void _tick(Timer t) {
    if (!isActive) { t.cancel(); return; }
    secondsLeft--;
    if (secondsLeft <= 0) {
      if (isWorking) { isWorking = false; secondsLeft = restSeconds; }
      else { if (currentRound >= totalRounds) { isFinished = true; isActive = false; t.cancel(); } else { currentRound++; isWorking = true; secondsLeft = workSeconds; } }
    }
    notifyListeners();
  }
  void pause() { isActive = false; notifyListeners(); }
  void resume() { if (!isFinished) isActive = true; notifyListeners(); }
  void reset() { _timer?.cancel(); isActive = false; isFinished = false; isWorking = true; currentRound = 1; secondsLeft = workSeconds; notifyListeners(); }
  void setWork(int s) { if (!isActive) { workSeconds = s; secondsLeft = s; notifyListeners(); } }
  void setRest(int s) { if (!isActive) { restSeconds = s; notifyListeners(); } }
  void setRounds(int n) { if (!isActive) { totalRounds = n; notifyListeners(); } }
  @override void dispose() { isActive = false; _timer?.cancel(); super.dispose(); }
}

class TimerCirclePainter extends CustomPainter {
  final int secondsLeft, totalSeconds; final bool isWorking;
  TimerCirclePainter(this.secondsLeft, this.totalSeconds, this.isWorking);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2); final r = size.width / 2 - 12;
    canvas.drawCircle(c, r, Paint()..color = kSurface..strokeWidth = 12..style = PaintingStyle.stroke);
    final sweep = 2 * pi * (totalSeconds > 0 ? secondsLeft / totalSeconds : 0);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, sweep, false, Paint()..color = isWorking ? kAccent : kError..strokeWidth = 12..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(TimerCirclePainter o) => o.secondsLeft != secondsLeft;
}

class TabataScreen extends StatelessWidget {
  const TabataScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<TabataController>();
    final totalSec = ctrl.isWorking ? ctrl.workSeconds : ctrl.restSeconds;
    return Scaffold(backgroundColor: kBg, body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      const Text('TABATA TIMER', style: TextStyle(color: kAccent, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      SizedBox(height: 200, child: Stack(alignment: Alignment.center, children: [
        CustomPaint(painter: TimerCirclePainter(ctrl.secondsLeft, totalSec, ctrl.isWorking), size: const Size(200, 200)),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${ctrl.secondsLeft}', style: TextStyle(color: ctrl.isWorking ? kAccent : kError, fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          Text(ctrl.isWorking ? 'TRABAJO' : 'DESCANSO', style: TextStyle(color: ctrl.isWorking ? kAccent : kError, fontSize: 14)).animate().fadeIn(duration: 300.ms),
        ]),
      ])),
      const SizedBox(height: 12),
      Text('RONDA ${ctrl.currentRound} / ${ctrl.totalRounds}', style: const TextStyle(color: kTextSub, fontSize: 16)),
      const SizedBox(height: 24),
      if (!ctrl.isActive && !ctrl.isFinished) ...[
        Row(children: [const SizedBox(width: 70, child: Text('Trabajo', style: TextStyle(color: kTextSub, fontSize: 12))), Expanded(child: Slider(value: ctrl.workSeconds.toDouble(), min: 10, max: 60, activeColor: kAccent, onChanged: (v) => ctrl.setWork(v.round()))), SizedBox(width: 30, child: Text('${ctrl.workSeconds}s', style: const TextStyle(color: kText, fontSize: 12)))]),
        Row(children: [const SizedBox(width: 70, child: Text('Descanso', style: TextStyle(color: kTextSub, fontSize: 12))), Expanded(child: Slider(value: ctrl.restSeconds.toDouble(), min: 5, max: 30, activeColor: kAccent, onChanged: (v) => ctrl.setRest(v.round()))), SizedBox(width: 30, child: Text('${ctrl.restSeconds}s', style: const TextStyle(color: kText, fontSize: 12)))]),
        Row(children: [const SizedBox(width: 70, child: Text('Rondas', style: TextStyle(color: kTextSub, fontSize: 12))), Expanded(child: Slider(value: ctrl.totalRounds.toDouble(), min: 2, max: 20, activeColor: kAccent, onChanged: (v) => ctrl.setRounds(v.round()))), SizedBox(width: 30, child: Text('${ctrl.totalRounds}', style: const TextStyle(color: kText, fontSize: 12)))]),
      ],
      const SizedBox(height: 16),
      if (ctrl.isFinished)
        Column(children: [const Text('TABATA COMPLETADO!', style: TextStyle(color: kAccent, fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 16), ElevatedButton(onPressed: ctrl.reset, style: ElevatedButton.styleFrom(backgroundColor: kAccent), child: const Text('REINICIAR', style: TextStyle(color: Colors.black)))])
      else
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          ElevatedButton(onPressed: ctrl.isActive ? ctrl.pause : (ctrl.currentRound > 1 ? ctrl.resume : ctrl.start), style: ElevatedButton.styleFrom(backgroundColor: ctrl.isActive ? kTextSub : kAccent), child: Text(ctrl.isActive ? 'PAUSAR' : ctrl.currentRound > 1 ? 'REANUDAR' : 'INICIAR', style: const TextStyle(color: Colors.black))),
          OutlinedButton(onPressed: ctrl.reset, style: OutlinedButton.styleFrom(side: const BorderSide(color: kTextSub)), child: const Text('RESET', style: TextStyle(color: kTextSub))),
        ]),
    ]))));
  }
}

// ═══ ETAPA 3 — EVOLUTION GALLERY + HISTORIAL ═══

class EvolutionEntry {
  final String date; final int level, xp, totalSessions;
  EvolutionEntry({required this.date, required this.level, required this.xp, required this.totalSessions});
  factory EvolutionEntry.fromMap(Map m) => EvolutionEntry(date: m['date']?.toString() ?? '', level: (m['level'] as num?)?.toInt() ?? 1, xp: (m['xp'] as num?)?.toInt() ?? 0, totalSessions: (m['totalSessions'] as num?)?.toInt() ?? 0);
  Map<String, dynamic> toMap() => {'date': date, 'level': level, 'xp': xp, 'totalSessions': totalSessions};
}

class EvolutionGalleryProvider extends ChangeNotifier {
  bool isLoading = true; List<EvolutionEntry> entries = [];
  Future<void> init() async {
    final box = Hive.box('evolution');
    entries = box.values.map((e) => EvolutionEntry.fromMap(e as Map)).toList()..sort((a, b) => b.date.compareTo(a.date));
    isLoading = false; notifyListeners();
  }
  Future<void> recordSnapshot(int level, int xp, int totalSessions) async {
    final date = DateTime.now().toIso8601String().split('T').first;
    await Hive.box('evolution').put(date, {'date': date, 'level': level, 'xp': xp, 'totalSessions': totalSessions});
    await init();
  }
  EvolutionEntry? get latestEntry => entries.isEmpty ? null : entries.first;
  EvolutionEntry? get oldestEntry => entries.isEmpty ? null : entries.last;
  int get totalLevelsGained => entries.length >= 2 ? (latestEntry!.level - oldestEntry!.level).abs() : 0;
}

class SessionLogProvider extends ChangeNotifier {
  bool isLoading = true; List<Map<String, dynamic>> sessions = [];
  Future<void> init() async {
    final box = Hive.box('sessions');
    sessions = box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList()..sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
    isLoading = false; notifyListeners();
  }
  Future<void> addSession(String exercise, int series, int reps, int xpGained) async {
    await Hive.box('sessions').add({'exercise': exercise, 'series': series, 'reps': reps, 'xpGained': xpGained, 'date': DateTime.now().toIso8601String()});
    await init();
  }
  int get totalSessions => sessions.length;
  double get avgXP => sessions.isEmpty ? 0 : sessions.map((s) => s['xpGained'] as int? ?? 0).reduce((a, b) => a + b) / sessions.length;
  Map<String, int> get exerciseCounts {
    final c = <String, int>{}; for (final s in sessions) { final ex = s['exercise'] ?? ''; c[ex] = (c[ex] ?? 0) + 1; } return c;
  }
}

class LevelUpPainter extends CustomPainter {
  final List<EvolutionEntry> entries;
  LevelUpPainter(this.entries);
  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) {
      final tp = TextPainter(text: const TextSpan(text: 'REGISTRA MAS SESIONES PARA VER TU PROGRESO', style: TextStyle(color: kTextSub, fontSize: 11)), textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(maxWidth: size.width);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2 - 10)); return;
    }
    final rev = entries.reversed.toList();
    final minL = rev.map((e) => e.level).reduce((a, b) => a < b ? a : b).toDouble();
    final maxL = rev.map((e) => e.level).reduce((a, b) => a > b ? a : b).toDouble();
    final range = (maxL - minL).clamp(1.0, double.infinity);
    final lp = Paint()..color = kAccent..strokeWidth = 2..style = PaintingStyle.stroke;
    final dp = Paint()..color = kAccent..style = PaintingStyle.fill;
    final pts = List.generate(rev.length, (i) => Offset(size.width * i / (rev.length - 1), size.height - 20 - (size.height - 30) * ((rev[i].level - minL) / range)));
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) path.lineTo(p.dx, p.dy);
    canvas.drawPath(path, lp);
    for (final p in pts) canvas.drawCircle(p, 4, dp);
  }
  @override bool shouldRepaint(LevelUpPainter o) => o.entries != entries;
}

class EvolutionGalleryScreen extends StatelessWidget {
  const EvolutionGalleryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final g = context.watch<EvolutionGalleryProvider>();
    final e = context.read<RPGEngine>();
    final s = context.watch<SessionLogProvider>();
    return Scaffold(backgroundColor: kBg, body: SafeArea(child: g.isLoading
      ? const Center(child: CircularProgressIndicator(color: kAccent))
      : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.trending_up, color: kAccent), SizedBox(width: 8), Text('GALERIA DE EVOLUCION', style: TextStyle(color: kAccent, fontSize: 18, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 16),
          Row(children: [_statCard('NIVEL', '${g.latestEntry?.level ?? e.level}'), const SizedBox(width: 8), _statCard('GANADOS', '${g.totalLevelsGained}'), const SizedBox(width: 8), _statCard('SESIONES', '${s.totalSessions}')]),
          const SizedBox(height: 16),
          Container(height: 180, decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(12), child: CustomPaint(painter: LevelUpPainter(g.entries), size: Size.infinite)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: kAccent, minimumSize: const Size(double.infinity, 48)),
            icon: const Icon(Icons.camera_alt, color: Colors.black),
            label: const Text('REGISTRAR SNAPSHOT HOY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () => g.recordSnapshot(e.level, e.xp, e.totalSessions),
          ),
          const SizedBox(height: 16),
          if (g.entries.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('PRESIONA EL BOTON PARA REGISTRAR TU PRIMER SNAPSHOT', style: TextStyle(color: kTextSub), textAlign: TextAlign.center)))
          else
            ...g.entries.map((en) => Card(color: kSurface, margin: const EdgeInsets.only(bottom: 4), child: ListTile(leading: Icon(Icons.star, color: en.level > 10 ? Colors.green : en.level > 5 ? kAccent : Colors.white, size: 20), title: Text('Nivel ${en.level}', style: const TextStyle(color: kText)), subtitle: Text(en.date, style: const TextStyle(color: kTextSub, fontSize: 11)), trailing: Text('${en.xp} XP', style: const TextStyle(color: kAccent, fontFamily: 'monospace'))))),
        ]))));
  }
}

class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});
  String _rel(String d) { try { final diff = DateTime.now().difference(DateTime.parse(d)).inDays; if (diff == 0) return 'Hoy'; if (diff == 1) return 'Ayer'; return 'Hace $diff dias'; } catch (_) { return d; } }
  IconData _icon(String ex) { switch (ex) { case 'Push-ups': return Icons.arrow_upward; case 'Pull-ups': return Icons.arrow_downward; case 'Dips': return Icons.south; case 'Squats': return Icons.airline_seat_legroom_extra; case 'Planks': return Icons.horizontal_rule; default: return Icons.fitness_center; } }
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionLogProvider>();
    final counts = s.exerciseCounts;
    final fav = counts.isEmpty ? '-' : counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return Scaffold(backgroundColor: kBg, body: SafeArea(child: s.isLoading
      ? const Center(child: CircularProgressIndicator(color: kAccent))
      : Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            const Row(children: [Icon(Icons.history, color: kAccent), SizedBox(width: 8), Text('HISTORIAL DE SESIONES', style: TextStyle(color: kAccent, fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 12),
            Row(children: [_statCard('TOTAL', '${s.totalSessions}'), const SizedBox(width: 8), _statCard('XP PROM', s.avgXP.toStringAsFixed(0)), const SizedBox(width: 8), _statCard('FAVORITO', fav.split('-').first)]),
          ])),
          Expanded(child: s.sessions.isEmpty
            ? const Center(child: Text('SIN SESIONES REGISTRADAS AUN', style: TextStyle(color: kTextSub)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: s.sessions.length,
                itemBuilder: (c, i) {
                  final sess = s.sessions[i];
                  return Card(color: kSurface, margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(_icon(sess['exercise'] ?? ''), color: kAccent), title: Text(sess['exercise'] ?? '', style: const TextStyle(color: kText)), subtitle: Text('${sess['series']}x${sess['reps']} · ${_rel(sess['date'] ?? '')}', style: const TextStyle(color: kTextSub, fontSize: 11)), trailing: Text('+${sess['xpGained']} XP', style: const TextStyle(color: kAccent, fontFamily: 'monospace'))));
                })),
        ])));
  }
}

// ═══ APP SHELL — 5 TABS ═══

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _ASState();
}
class _ASState extends State<AppShell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: IndexedStack(index: _i, children: const [HomeScreen(), DashboardScreen(), TabataScreen(), EvolutionGalleryScreen(), SessionHistoryScreen()]),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _i,
      onTap: (i) => setState(() => _i = i),
      backgroundColor: kSurface,
      selectedItemColor: kAccent,
      unselectedItemColor: kTextSub,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 10, unselectedFontSize: 10,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'ENTRENA'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'STATS'),
        BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'TABATA'),
        BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'EVOLUCION'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'HISTORIAL'),
      ],
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Calisthenics Level Up',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: kBg, colorScheme: const ColorScheme.dark(primary: kAccent, secondary: kAccent2)),
    home: const AppShell(),
  );
}
