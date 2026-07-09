import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/rpg_engine.dart';
import '../painters/body_painter.dart';
import '../painters/line_painter.dart';

class MuscleMapScreen extends StatefulWidget {
  const MuscleMapScreen({super.key});

  @override
  State<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends State<MuscleMapScreen>
    with TickerProviderStateMixin {
  bool _frontal = true;
  late AnimationController _aura;
  late Animation<double> _auraAnim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _aura = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _auraAnim = CurvedAnimation(parent: _aura, curve: Curves.easeInOut);
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _aura.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RPGEngine>(builder: (_, engine, __) {
      final muscles =
          _frontal ? engine.musculosFrontales : engine.musculosPosteriores;
      return Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _toggleBtn('FRENTE', _frontal, () => setState(() => _frontal = true)),
            const SizedBox(width: 12),
            _toggleBtn('ESPALDA', !_frontal, () => setState(() => _frontal = false)),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (ctx, box) {
            final panelW = box.maxWidth * 0.52;
            final panelH = box.maxHeight * 0.88;
            final cx = box.maxWidth / 2;
            final pt = (box.maxHeight - panelH) / 2;
            return Stack(children: [
              // Aura glow
              Center(
                child: AnimatedBuilder(
                  animation: _auraAnim,
                  builder: (_, __) => Container(
                    width: panelW + 20,
                    height: panelH + 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(62),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withOpacity(0.10 + 0.15 * _auraAnim.value),
                          blurRadius: 20 + 20 * _auraAnim.value,
                          spreadRadius: 3 * _auraAnim.value,
                        )
                      ],
                    ),
                  ),
                ),
              ),
              // Body panel
              Center(
                child: Container(
                  width: panelW,
                  height: panelH,
                  decoration: BoxDecoration(
                    color: const Color(0xFF080812),
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(color: kAccent.withOpacity(0.5), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(58),
                    child: CustomPaint(
                      painter: BodyPainter(muscles: muscles, frontal: _frontal),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
              // Labels
              ...muscles.map((m) {
                final mx = cx - panelW / 2 + m.posRelativa.dx * panelW;
                final my = pt + m.posRelativa.dy * panelH;
                final lw = box.maxWidth * 0.22;
                final lx = m.labelSide > 0
                    ? (cx + panelW / 2 + 8).clamp(0.0, box.maxWidth - lw)
                    : 2.0;
                final ly = (my - 18).clamp(pt, pt + panelH - 50);
                final color = m.statusColor;
                final h = m.tiempoRestante.inHours;
                final min = m.tiempoRestante.inMinutes % 60;
                final timeStr = m.enCooldown
                    ? '${h.toString().padLeft(2, "0")}H ${min.toString().padLeft(2, "0")}M'
                    : 'READY';
                return Positioned(
                  left: lx,
                  top: ly,
                  width: lw,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: LinePainter(
                          x1: m.labelSide > 0 ? 0 : lw,
                          y1: 16,
                          x2: mx - lx,
                          y2: my - ly,
                          color: color.withOpacity(0.5),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A14),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withOpacity(0.8)),
                        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.nombre,
                              style: const TextStyle(
                                  color: kText, fontSize: 10, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                          Text(timeStr,
                              style: TextStyle(
                                  color: color, fontSize: 9, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ]),
                );
              }),
            ]);
          }),
        ),
      ]);
    });
  }

  Widget _toggleBtn(String l, bool a, VoidCallback fn) => GestureDetector(
        onTap: fn,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: a ? kAccent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: a ? kAccent : kTextSub),
            boxShadow: a ? [BoxShadow(color: kAccent.withOpacity(0.3), blurRadius: 8)] : [],
          ),
          child: Text(l,
              style: TextStyle(
                  color: a ? kAccent : kTextSub,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      );
}
