import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/rpg_engine.dart';
import '../widgets/rank_badge.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _series = 3, _reps = 10;
  String? _sel;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RPGEngine>(builder: (_, engine, __) {
      final libres = engine.muscles.where((m) => !m.enCooldown).toList();
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // XP card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: kPanel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccent.withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('NIVEL ${engine.level}',
                    style: const TextStyle(
                        color: kAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                RankBadge(rank: engine.rank, color: engine.rankColor),
                Text('${engine.xp}/${engine.requiredXP} XP',
                    style: const TextStyle(color: kTextSub, fontSize: 11)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: engine.xpPercent.clamp(0.0, 1.0),
                  backgroundColor: kAccent.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(kAccent),
                  minHeight: 8,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('MUSCULO A ENTRENAR',
              style: TextStyle(color: kTextSub, fontSize: 11, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          libres.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: kPanel,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kCritico.withOpacity(0.5))),
                  child: const Row(children: [
                    Icon(Icons.timer, color: kCritico, size: 18),
                    SizedBox(width: 8),
                    Text('Todos los musculos en recuperacion',
                        style: TextStyle(color: kCritico)),
                  ]))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: libres.map((m) {
                    final sel = _sel == m.id;
                    return GestureDetector(
                      onTap: () => setState(() => _sel = m.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? kAccent.withOpacity(0.15) : kPanel,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: sel ? kAccent : kTextSub.withOpacity(0.4)),
                          boxShadow: sel
                              ? [BoxShadow(color: kAccent.withOpacity(0.3), blurRadius: 8)]
                              : [],
                        ),
                        child: Text(m.nombre,
                            style: TextStyle(
                                color: sel ? kAccent : kText, fontSize: 12)),
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 16),
          const Text('SERIES',
              style: TextStyle(color: kTextSub, fontSize: 11, letterSpacing: 1.5)),
          Row(children: [
            Text('$_series',
                style: const TextStyle(
                    color: kAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
            Expanded(
              child: Slider(
                value: _series.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: kAccent,
                inactiveColor: kAccent.withOpacity(0.2),
                onChanged: (v) => setState(() => _series = v.round()),
              ),
            ),
          ]),
          const Text('REPETICIONES',
              style: TextStyle(color: kTextSub, fontSize: 11, letterSpacing: 1.5)),
          Row(children: [
            Text('$_reps',
                style: const TextStyle(
                    color: kAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
            Expanded(
              child: Slider(
                value: _reps.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                activeColor: kAccent,
                inactiveColor: kAccent.withOpacity(0.2),
                onChanged: (v) => setState(() => _reps = v.round()),
              ),
            ),
          ]),
          if (_sel != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: kPanel, borderRadius: BorderRadius.circular(8)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('XP a ganar: +${_series * _reps * 2}',
                        style: const TextStyle(
                            color: kGold, fontWeight: FontWeight.bold)),
                    Text(
                        'Cooldown: ~${((_series * _reps * 0.5) / 2.0).clamp(12.0, 72.0).round()}h',
                        style:
                            const TextStyle(color: kTextSub, fontSize: 12)),
                  ]),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _sel != null ? kAccent : kTextSub.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: _sel != null ? 8 : 0,
                shadowColor: _sel != null
                    ? kAccent.withOpacity(0.5)
                    : Colors.transparent,
              ),
              onPressed: _sel == null
                  ? null
                  : () async {
                      await engine.registerSession(_sel!, _series, _reps);
                      setState(() => _sel = null);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Sesion registrada!'),
                          backgroundColor: kOptimo.withOpacity(0.8),
                          duration: const Duration(seconds: 2),
                        ));
                      }
                    },
              child: const Text('REGISTRAR SESION',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.5)),
            ),
          ),
          const SizedBox(height: 20),
          if (engine.muscles.any((m) => m.enCooldown)) ...[
            const Text('EN RECUPERACION',
                style: TextStyle(color: kTextSub, fontSize: 11, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            ...engine.muscles.where((m) => m.enCooldown).map((m) {
              final c = m.statusColor;
              final h = m.tiempoRestante.inHours;
              final min = m.tiempoRestante.inMinutes % 60;
              final t =
                  '${h.toString().padLeft(2, "0")}H ${min.toString().padLeft(2, "0")}M';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: kPanel,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withOpacity(0.5))),
                child: Row(children: [
                  Icon(Icons.timer, color: c, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(m.nombre,
                          style: const TextStyle(color: kText, fontSize: 13))),
                  Text('REC: $t',
                      style: TextStyle(
                          color: c,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold)),
                ]),
              );
            }),
          ],
        ]),
      );
    });
  }
}
