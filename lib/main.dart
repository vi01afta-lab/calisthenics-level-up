import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

const kBg = Color(0xFF0A0A0F);
const kPanel = Color(0xFF12121A);
const kAccent = Color(0xFF00D4FF);
const kAccent2 = Color(0xFF7B2FBE);
const kGold = Color(0xFFFFD700);
const kCritico = Color(0xFFFF3B30);
const kPrecaucion = Color(0xFFFF9500);
const kOptimo = Color(0xFF39FF14);
const kText = Color(0xFFE0E0E0);
const kTextSub = Color(0xFF666699);

enum MuscleStatus { optimo, precaucion, critico }

class MuscleData {
  final String id;
  final String nombre;
  final bool esFrontal;
  final Offset posRelativa;
  final double labelSide;
  DateTime? cooldownExpiry;

  MuscleData({required this.id, required this.nombre, required this.esFrontal,
    required this.posRelativa, required this.labelSide, this.cooldownExpiry});

  bool get enCooldown => cooldownExpiry != null && DateTime.now().isBefore(cooldownExpiry!);

  Duration get tiempoRestante {
    if (cooldownExpiry == null) return Duration.zero;
    final r = cooldownExpiry!.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  MuscleStatus get status {
    if (!enCooldown) return MuscleStatus.optimo;
    return tiempoRestante.inHours >= 24 ? MuscleStatus.critico : MuscleStatus.precaucion;
  }

  Color get statusColor {
    switch (status) {
      case MuscleStatus.critico: return kCritico;
      case MuscleStatus.precaucion: return kPrecaucion;
      case MuscleStatus.optimo: return kOptimo;
    }
  }
}

class RPGEngine extends ChangeNotifier {
  int level = 1, xp = 0, totalSessions = 0;

  final List<MuscleData> muscles = [
    MuscleData(id: 'pectoral', nombre: 'Pectoral Mayor', esFrontal: true, posRelativa: const Offset(0.5, 0.29), labelSide: 1),
    MuscleData(id: 'biceps', nombre: 'Biceps', esFrontal: true, posRelativa: const Offset(0.10, 0.30), labelSide: -1),
    MuscleData(id: 'deltoides', nombre: 'Deltoides', esFrontal: true, posRelativa: const Offset(0.18, 0.21), labelSide: -1),
    MuscleData(id: 'core', nombre: 'Recto Abdominal', esFrontal: true, posRelativa: const Offset(0.5, 0.41), labelSide: 1),
    MuscleData(id: 'cuadriceps', nombre: 'Cuadriceps', esFrontal: true, posRelativa: const Offset(0.37, 0.67), labelSide: -1),
    MuscleData(id: 'dorsal', nombre: 'Dorsal Ancho', esFrontal: false, posRelativa: const Offset(0.5, 0.31), labelSide: -1),
    MuscleData(id: 'triceps', nombre: 'Triceps', esFrontal: false, posRelativa: const Offset(0.90, 0.30), labelSide: 1),
    MuscleData(id: 'gluteo', nombre: 'Gluteo Mayor', esFrontal: false, posRelativa: const Offset(0.5, 0.535), labelSide: 1),
    MuscleData(id: 'isquio', nombre: 'Isquiotibiales', esFrontal: false, posRelativa: const Offset(0.37, 0.67), labelSide: -1),
    MuscleData(id: 'trapecio', nombre: 'Trapecio', esFrontal: false, posRelativa: const Offset(0.5, 0.195), labelSide: 1),
  ];

  int get requiredXP => (100 * pow(level, 1.5)).round();
  double get xpPercent => xp / requiredXP;
  double get mpValue { final l = muscles.where((m) => !m.enCooldown).length; return l / muscles.length; }

  String get rank {
    if (level >= 50) return 'SSS';
    if (level >= 41) return 'S';
    if (level >= 31) return 'A';
    if (level >= 21) return 'B';
    if (level >= 11) return 'C';
    if (level >= 5) return 'D';
    return 'E';
  }

  Color get rankColor {
    switch (rank) {
      case 'SSS': return const Color(0xFFFF0000);
      case 'S': return const Color(0xFFFF6B00);
      case 'A': return kAccent2;
      case 'B': return kAccent;
      case 'C': return kGold;
      case 'D': return const Color(0xFFC0C0C0);
      default: return const Color(0xFFCD7F32);
    }
  }

  List<MuscleData> get musculosFrontales => muscles.where((m) => m.esFrontal).toList();
  List<MuscleData> get musculosPosteriores => muscles.where((m) => !m.esFrontal).toList();

  void loadFromHive() {
    try {
      final box = Hive.box('user_data');
      level = box.get('level', defaultValue: 1);
      xp = box.get('xp', defaultValue: 0);
      totalSessions = box.get('totalSessions', defaultValue: 0);
      for (final m in muscles) {
        final s = box.get('cd_${m.id}');
        if (s != null) m.cooldownExpiry = DateTime.tryParse(s);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> registerSession(String muscleId, int series, int reps) async {
    final list = muscles.where((x) => x.id == muscleId).toList();
    if (list.isEmpty || list.first.enCooldown) return;
    final m = list.first;
    final xpGained = series * reps * 2;
    final cdH = ((series * reps * 0.5) / 2.0).clamp(12.0, 72.0);
    xp += xpGained; totalSessions++;
    m.cooldownExpiry = DateTime.now().add(Duration(hours: cdH.round()));
    while (xp >= requiredXP) { xp -= requiredXP; level++; }
    try {
      final box = Hive.box('user_data');
      await box.putAll({'level': level, 'xp': xp, 'totalSessions': totalSessions, 'cd_${m.id}': m.cooldownExpiry!.toIso8601String()});
    } catch (_) {}
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid)
            .set({'level': level, 'xp': xp, 'totalSessions': totalSessions}, SetOptions(merge: true));
      }
    } catch (_) {}
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (e) { debugPrint('Firebase: $e'); }
  try { await FirebaseAuth.instance.signInAnonymously(); } catch (e) {}
  await Hive.initFlutter();
  await Hive.openBox('user_data');
  runApp(ChangeNotifierProvider(create: (_) => RPGEngine()..loadFromHive(), child: const MyApp()));
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        Expanded(child: IndexedStack(index: _tab, children: const [MuscleMapScreen(), RegisterScreen()])),
        _buildNav(),
      ])),
    );
  }

  Widget _buildHeader() {
    return Consumer<RPGEngine>(builder: (_, e, __) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: kPanel,
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('NVL ${e.level} ', style: const TextStyle(color: kAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: e.rankColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4),
                border: Border.all(color: e.rankColor), boxShadow: [BoxShadow(color: e.rankColor.withOpacity(0.4), blurRadius: 6)]),
              child: Text('RANGO ${e.rank}', style: TextStyle(color: e.rankColor, fontSize: 11, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 4),
          SizedBox(width: 160, child: Column(children: [
            _sbar('HP', e.xpPercent.clamp(0.0, 1.0), kCritico),
            const SizedBox(height: 2),
            _sbar('MP', e.mpValue, kAccent),
            const SizedBox(height: 2),
            _sbar('SP', 1.0, kOptimo),
          ])),
        ]),
        const Spacer(),
        Text('${e.xp}/${e.requiredXP} XP', style: const TextStyle(color: kTextSub, fontSize: 10)),
      ]),
    ));
  }

  Widget _sbar(String l, double v, Color c) => Row(children: [
    SizedBox(width: 20, child: Text(l, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold))),
    const SizedBox(width: 4),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(value: v, backgroundColor: c.withOpacity(0.15),
        valueColor: AlwaysStoppedAnimation(c), minHeight: 5))),
  ]);

  Widget _buildNav() => Container(color: kPanel, child: Row(children: [
    _nb(0, Icons.accessibility_new, 'MAPA'), _nb(1, Icons.fitness_center, 'ENTRENAR'),
  ]));

  Widget _nb(int i, IconData icon, String l) {
    final s = _tab == i;
    return Expanded(child: InkWell(onTap: () => setState(() => _tab = i),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: s ? kAccent : Colors.transparent, width: 2))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: s ? kAccent : kTextSub, size: 20),
          Text(l, style: TextStyle(color: s ? kAccent : kTextSub, fontSize: 10)),
        ]))));
  }
}

class MuscleMapScreen extends StatefulWidget {
  const MuscleMapScreen({super.key});
  @override State<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends State<MuscleMapScreen> with TickerProviderStateMixin {
  bool _frontal = true;
  late AnimationController _aura;
  late Animation<double> _auraAnim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _aura = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _auraAnim = CurvedAnimation(parent: _aura, curve: Curves.easeInOut);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _aura.dispose(); _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<RPGEngine>(builder: (_, engine, __) {
      final muscles = _frontal ? engine.musculosFrontales : engine.musculosPosteriores;
      return Column(children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _toggleBtn('FRENTE', _frontal, () => setState(() => _frontal = true)),
            const SizedBox(width: 12),
            _toggleBtn('ESPALDA', !_frontal, () => setState(() => _frontal = false)),
          ])),
        Expanded(child: LayoutBuilder(builder: (ctx, box) {
          final panelW = box.maxWidth * 0.52;
          final panelH = box.maxHeight * 0.88;
          final cx = box.maxWidth / 2;
          final pt = (box.maxHeight - panelH) / 2;
          return Stack(children: [
            Center(child: AnimatedBuilder(animation: _auraAnim, builder: (_, __) => Container(
              width: panelW + 20, height: panelH + 20,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(62),
                boxShadow: [BoxShadow(color: kAccent.withOpacity(0.1 + 0.15 * _auraAnim.value),
                  blurRadius: 20 + 20 * _auraAnim.value, spreadRadius: 3 * _auraAnim.value)])))),
            Center(child: Container(width: panelW, height: panelH,
              decoration: BoxDecoration(color: const Color(0xFF080812),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(color: kAccent.withOpacity(0.5), width: 1.5)),
              child: ClipRRect(borderRadius: BorderRadius.circular(58),
                child: CustomPaint(painter: BodyPainter(muscles: muscles, frontal: _frontal), size: Size.infinite)))),
            ...muscles.map((m) {
              final mx = cx - panelW / 2 + m.posRelativa.dx * panelW;
              final my = pt + m.posRelativa.dy * panelH;
              final lw = box.maxWidth * 0.22;
              final lx = m.labelSide > 0 ? (cx + panelW / 2 + 8).clamp(0.0, box.maxWidth - lw) : (2.0);
              final ly = (my - 18).clamp(pt, pt + panelH - 50);
              final color = m.statusColor;
              final h = m.tiempoRestante.inHours;
              final min = m.tiempoRestante.inMinutes % 60;
              final timeStr = m.enCooldown ? '${h.toString().padLeft(2, "0")}H ${min.toString().padLeft(2, "0")}M' : 'READY';
              return Positioned(left: lx, top: ly, width: lw,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(child: CustomPaint(painter: LinePainter(
                    x1: m.labelSide > 0 ? 0 : lw, y1: 16,
                    x2: mx - lx, y2: my - ly, color: color.withOpacity(0.5)))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF0A0A14), borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.8)),
                      boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(m.nombre, style: const TextStyle(color: kText, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      Text(timeStr, style: TextStyle(color: color, fontSize: 8, fontFamily: 'monospace')),
                    ])),
                ]));
            }),
          ]);
        })),
      ]);
    });
  }

  Widget _toggleBtn(String l, bool a, VoidCallback fn) => GestureDetector(onTap: fn,
    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(color: a ? kAccent.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6), border: Border.all(color: a ? kAccent : kTextSub),
        boxShadow: a ? [BoxShadow(color: kAccent.withOpacity(0.3), blurRadius: 8)] : []),
      child: Text(l, style: TextStyle(color: a ? kAccent : kTextSub, fontSize: 12, fontWeight: FontWeight.bold))));
}

class BodyPainter extends CustomPainter {
  final List<MuscleData> muscles;
  final bool frontal;
  BodyPainter({required this.muscles, required this.frontal});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = RadialGradient(
      colors: [const Color(0xFF0D1520), const Color(0xFF080810)]).createShader(Rect.fromLTWH(0,0,w,h)));
    final fp = Paint()..color = const Color(0xFF1A2535)..style = PaintingStyle.fill;
    final bp = Paint()..color = kAccent.withOpacity(0.22)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    void dr(Path p) { canvas.drawPath(p, fp); canvas.drawPath(p, bp); }
    // head
    dr(Path()..addOval(Rect.fromCenter(center: Offset(w*.5,h*.08), width: w*.24, height: h*.11)));
    // neck
    dr(Path()..addRect(Rect.fromCenter(center: Offset(w*.5,h*.145), width: w*.10, height: h*.04)));
    // torso
    dr(Path()..moveTo(w*.18,h*.165)..lineTo(w*.82,h*.165)..lineTo(w*.72,h*.52)..lineTo(w*.28,h*.52)..close());
    // left arm
    dr(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.03,h*.175,w*.14,h*.32), const Radius.circular(12))));
    // right arm
    dr(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.83,h*.175,w*.14,h*.32), const Radius.circular(12))));
    // left leg
    dr(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.28,h*.53,w*.18,h*.42), const Radius.circular(12))));
    // right leg
    dr(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.54,h*.53,w*.18,h*.42), const Radius.circular(12))));

    for (final m in muscles) {
      final c = m.statusColor;
      final fillP = Paint()..color = c.withOpacity(m.enCooldown ? 0.38 : 0.18)..style = PaintingStyle.fill;
      final glowP = Paint()..color = c.withOpacity(0.65)..style = PaintingStyle.stroke..strokeWidth = 1.5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m.enCooldown ? 4 : 2);
      Path? p;
      switch (m.id) {
        case 'pectoral':
          p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(w*.5,h*.27),width:w*.48,height:h*.10),const Radius.circular(8))); break;
        case 'biceps':
          p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(w*.10,h*.28),width:w*.10,height:h*.14),const Radius.circular(6))); break;
        case 'deltoides':
          p = Path()..addOval(Rect.fromCenter(center:Offset(w*.185,h*.205),width:w*.13,height:h*.07)); break;
        case 'core':
          p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(w*.5,h*.40),width:w*.32,height:h*.14),const Radius.circular(6))); break;
        case 'cuadriceps':
          for (final x in [w*.29, w*.55]) {
            final q = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,h*.545,w*.16,h*.20),const Radius.circular(8)));
            canvas.drawPath(q, fillP); canvas.drawPath(q, glowP);
          }
          continue;
        case 'dorsal':
          p = Path()..moveTo(w*.2,h*.19)..lineTo(w*.8,h*.19)..lineTo(w*.7,h*.46)..lineTo(w*.3,h*.46)..close(); break;
        case 'triceps':
          p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(w*.90,h*.30),width:w*.10,height:h*.14),const Radius.circular(6))); break;
        case 'gluteo':
          p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(w*.5,h*.535),width:w*.46,height:h*.07),const Radius.circular(8))); break;
        case 'isquio':
          for (final x in [w*.29, w*.55]) {
            final q = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,h*.60,w*.16,h*.20),const Radius.circular(8)));
            canvas.drawPath(q, fillP); canvas.drawPath(q, glowP);
          }
          continue;
        case 'trapecio':
          p = Path()..moveTo(w*.35,h*.13)..lineTo(w*.65,h*.13)..lineTo(w*.72,h*.23)..lineTo(w*.28,h*.23)..close(); break;
      }
      if (p != null) { canvas.drawPath(p, fillP); canvas.drawPath(p, glowP); }
    }
  }
  @override bool shouldRepaint(_) => true;
}

class LinePainter extends CustomPainter {
  final double x1, y1, x2, y2; final Color color;
  LinePainter({required this.x1,required this.y1,required this.x2,required this.y2,required this.color});
  @override void paint(Canvas c, Size s) =>
    c.drawLine(Offset(x1,y1), Offset(x2,y2), Paint()..color=color..strokeWidth=1.0);
  @override bool shouldRepaint(_) => false;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _series = 3, _reps = 10;
  String? _sel;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<RPGEngine>(builder: (_, engine, __) {
      final libres = engine.muscles.where((m) => !m.enCooldown).toList();
      return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAccent.withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('NIVEL ${engine.level}', style: const TextStyle(color: kAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: engine.rankColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4), border: Border.all(color: engine.rankColor),
                    boxShadow: [BoxShadow(color: engine.rankColor.withOpacity(0.4), blurRadius: 6)]),
                  child: Text('RANGO ${engine.rank}', style: TextStyle(color: engine.rankColor, fontSize: 12, fontWeight: FontWeight.bold))),
                Text('${engine.xp}/${engine.requiredXP} XP', style: const TextStyle(color: kTextSub, fontSize: 11)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: engine.xpPercent.clamp(0.0,1.0),
                  backgroundColor: kAccent.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(kAccent), minHeight: 8)),
            ])),
          const SizedBox(height: 16),
          const Text('MUSCULO A ENTRENAR', style: TextStyle(color: kTextSub, fontSize: 11, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          libres.isEmpty
            ? Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(8), border: Border.all(color: kCritico.withOpacity(0.5))),
                child: const Row(children: [Icon(Icons.timer, color: kCritico, size: 18), SizedBox(width: 8), Text('Todos los musculos en recuperacion', style: TextStyle(color: kCritico))]))
            : Wrap(spacing: 8, runSpacing: 8, children: libres.map((m) {
                final sel = _sel == m.id;
                return GestureDetector(onTap: () => setState(() => _sel = m.id),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: sel ? kAccent.withOpacity(0.15) : kPanel,
                      borderRadius: BorderRadius.circular(6), border: Border.all(color: sel ? kAccent : kTextSub.withOpacity(0.4)),
                      boxShadow: sel ? [BoxShadow(color: kAccent.withOpacity(0.3), blurRadius: 8)] : []),
                    child: Text(m.nombre, style: TextStyle(color: sel ? kAccent : kText, fontSize: 12))));
              }).toList()),
          const SizedBox(height: 16),
          const Text('SERIES', style: TextStyle(color: kTextSub, fontSize: 11, letterSpacing: 1.5)),
          Row(children: [
            Text('$_series', style: const TextStyle(color: kAccent, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            Expanded(child: Slider(value: _series.toDouble(), min: 1, max: 10, divisions: 9,
              activeColor: kAccent, inactiveColor: kAccent.withOpacity(0.2),
              onChanged: (v) => setState(() => _series = v.round()))),
          ]),
          const Text('REPETICIONES', style: TextStyle(color: kTextSub, fontSize: 11, letterSpacing: 1.5)),
          Row(children: [
            Text('$_reps', style: const TextStyle(color: kAccent, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            Expanded(child: Slider(value: _reps.toDouble(), min: 1, max: 30, divisions: 29,
              activeColor: kAccent, inactiveColor: kAccent.withOpacity(0.2),
              onChanged: (v) => setState(() => _reps = v.round()))),
          ]),
          if (_sel != null) ...[
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('XP a ganar: +${_series * _reps * 2}', style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
                Text('Cooldown: ~${((_series * _reps * 0.5) / 2.0).clamp(12.0, 72.0).round()}h', style: const TextStyle(color: kTextSub, fontSize: 12)),
              ])),
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _sel != null ? kAccent : kTextSub.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: _sel != null ? 8 : 0,
              shadowColor: _sel != null ? kAccent.withOpacity(0.5) : Colors.transparent),
            onPressed: _sel == null ? null : () async {
              await engine.registerSession(_sel!, _series, _reps);
              setState(() => _sel = null);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Sesion registrada!'), backgroundColor: kOptimo.withOpacity(0.8), duration: const Duration(seconds: 2)));
            },
            child: const Text('REGISTRAR SESION', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5)))),
          const SizedBox(height: 20),
          if (engine.muscles.any((m) => m.enCooldown)) ...[
            const Text('EN RECUPERACION', style: TextStyle(color: kTextSub, fontSize: 11, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            ...engine.muscles.where((m) => m.enCooldown).map((m) {
              final c = m.statusColor;
              final h = m.tiempoRestante.inHours;
              final min = m.tiempoRestante.inMinutes % 60;
              final t = '${h.toString().padLeft(2,"0")}H ${min.toString().padLeft(2,"0")}M';
              return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withOpacity(0.5))),
                child: Row(children: [
                  Icon(Icons.timer, color: c, size: 16), const SizedBox(width: 8),
                  Expanded(child: Text(m.nombre, style: const TextStyle(color: kText, fontSize: 13))),
                  Text('REC: $t', style: TextStyle(color: c, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ]));
            }),
          ],
        ]));
    });
  }
}
