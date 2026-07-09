import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/rpg_engine.dart';
import '../widgets/rank_badge.dart';
import 'muscle_map_screen.dart';
import 'register_screen.dart';
import 'tabata_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [MuscleMapScreen(), RegisterScreen(), TabataScreen()],
            ),
          ),
          _buildNav(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<RPGEngine>(
      builder: (_, e, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: kPanel,
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('NVL ${e.level} ',
                  style: const TextStyle(
                      color: kAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              RankBadge(rank: e.rank, color: e.rankColor),
            ]),
            const SizedBox(height: 4),
            SizedBox(
              width: 160,
              child: Column(children: [
                _sbar('HP', e.xpPercent.clamp(0.0, 1.0), kCritico),
                const SizedBox(height: 2),
                _sbar('MP', e.mpValue, kAccent),
                const SizedBox(height: 2),
                _sbar('SP', 1.0, kOptimo),
              ]),
            ),
          ]),
          const Spacer(),
          Text('${e.xp}/${e.requiredXP} XP',
              style: const TextStyle(color: kTextSub, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _sbar(String l, double v, Color c) => Row(children: [
        SizedBox(
            width: 20,
            child: Text(l,
                style: TextStyle(
                    color: c, fontSize: 9, fontWeight: FontWeight.bold))),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: v,
              backgroundColor: c.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(c),
              minHeight: 5,
            ),
          ),
        ),
      ]);

  Widget _buildNav() => Container(
        color: kPanel,
        child: Row(children: [
          _nb(0, Icons.accessibility_new, 'MAPA'),
          _nb(1, Icons.fitness_center, 'ENTRENAR'),
          _nb(2, Icons.timer, 'TABATA'),
        ]),
      );

  Widget _nb(int i, IconData icon, String l) {
    final s = _tab == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(
                    color: s ? kAccent : Colors.transparent, width: 2)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: s ? kAccent : kTextSub, size: 20),
              Text(l,
                  style: TextStyle(color: s ? kAccent : kTextSub, fontSize: 10)),
            ]),
          ),
        ),
      );
    }
}
