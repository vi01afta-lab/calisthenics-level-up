import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';

enum TabataPhase { preparacion, trabajo, descanso, completo }

class TabataScreen extends StatefulWidget {
  const TabataScreen({super.key});

  @override
  State<TabataScreen> createState() => _TabataScreenState();
}

class _TabataScreenState extends State<TabataScreen> {
  TabataPhase _phase = TabataPhase.preparacion;
  int _secondsLeft = 10;
  int _currentRound = 0;
  static const int totalRounds = 8;
  Timer? _timer;
  bool _running = false;

  static const Map<TabataPhase, int> _phaseDuration = {
    TabataPhase.preparacion: 10,
    TabataPhase.trabajo: 20,
    TabataPhase.descanso: 10,
  };

  static const Map<TabataPhase, String> _phaseLabel = {
    TabataPhase.preparacion: 'PREPARA',
    TabataPhase.trabajo: 'TRABAJO',
    TabataPhase.descanso: 'DESCANSO',
    TabataPhase.completo: 'COMPLETO',
  };

  static const Map<TabataPhase, Color> _phaseColor = {
    TabataPhase.preparacion: kGold,
    TabataPhase.trabajo: kAccent,
    TabataPhase.descanso: kCritico,
    TabataPhase.completo: kOptimo,
  };

  void _start() {
    setState(() {
      _phase = TabataPhase.preparacion;
      _secondsLeft = 10;
      _currentRound = 0;
      _running = true;
    });
    _tick();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _nextPhase();
        }
      });
    });
  }

  void _nextPhase() {
    switch (_phase) {
      case TabataPhase.preparacion:
        _phase = TabataPhase.trabajo;
        _secondsLeft = 20;
        _currentRound = 1;
        break;
      case TabataPhase.trabajo:
        if (_currentRound >= totalRounds) {
          _phase = TabataPhase.completo;
          _running = false;
          _timer?.cancel();
        } else {
          _phase = TabataPhase.descanso;
          _secondsLeft = 10;
        }
        break;
      case TabataPhase.descanso:
        _phase = TabataPhase.trabajo;
        _secondsLeft = 20;
        _currentRound++;
        break;
      case TabataPhase.completo:
        break;
    }
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _resume() {
    setState(() => _running = true);
    _tick();
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _phase = TabataPhase.preparacion;
      _secondsLeft = 10;
      _currentRound = 0;
      _running = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _phaseColor[_phase] ?? kAccent;
    final label = _phaseLabel[_phase] ?? '';
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('TABATA TIMER',
                style: TextStyle(
                    color: kAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3)),
            const SizedBox(height: 8),
            if (_phase != TabataPhase.completo)
              Text('RONDA $_currentRound/$totalRounds',
                  style: const TextStyle(color: kTextSub, fontSize: 14)),
            const SizedBox(height: 32),
            // Timer circle
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPanel,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)
                ],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(
                  _phase == TabataPhase.completo
                      ? '✓'
                      : _secondsLeft.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: color,
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                if (_phase != TabataPhase.completo)
                  Text('segundos',
                      style: const TextStyle(color: kTextSub, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 40),
            // Controls
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (!_running && _phase == TabataPhase.preparacion && _currentRound == 0)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _start,
                  child: const Text('INICIAR',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                )
              else if (_phase != TabataPhase.completo) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _running ? kPrecaucion : kOptimo,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _running ? _pause : _resume,
                  child: Text(_running ? 'PAUSAR' : 'CONTINUAR',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kCritico),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _reset,
                  child: const Text('RESET', style: TextStyle(color: kCritico)),
                ),
              ] else ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kOptimo,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _reset,
                  child: const Text('NUEVA SESION',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
            const SizedBox(height: 24),
            // Phase sequence indicator
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _phaseChip('PREP 10s', _phase == TabataPhase.preparacion, kGold),
              const SizedBox(width: 8),
              _phaseChip('TRABAJO 20s', _phase == TabataPhase.trabajo, kAccent),
              const SizedBox(width: 8),
              _phaseChip('DESCANSO 10s', _phase == TabataPhase.descanso, kCritico),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _phaseChip(String l, bool a, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: a ? c.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: a ? c : kTextSub.withOpacity(0.3)),
        ),
        child: Text(l, style: TextStyle(color: a ? c : kTextSub, fontSize: 9)),
      );
}
