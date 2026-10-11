import 'package:flutter/material.dart';
import '../theme/arcade_config.dart';
import '../engine/arcade_engine.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';

class MenuScreen extends StatefulWidget {
  final ArcadeConfig config;
  const MenuScreen({super.key, required this.config});
  @override State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int highScore = 0;
  String playerName = 'Player 1';

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = SettingsService('${widget.config.slug}_');
    final h = await svc.getHighScore();
    final n = await svc.getPlayerName();
    if (mounted) setState(() { highScore = h; playerName = n; });
  }

  void _play() async {
    final svc = SettingsService('${widget.config.slug}_');
    final diff = await svc.getDifficulty();
    final shape = await svc.getShape();
    final mul = [0.8, 1.0, 1.3][diff.clamp(0, 2)];
    final sound = SoundService('${widget.config.slug}_');
    await sound.load();
    await sound.click();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(
      config: widget.config,
      engine: ArcadeEngine(cfg: widget.config, diffMul: mul),
      sound: sound,
      shape: shape,
    ))).then((_) => _load());
  }

  @override Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [c.darkColor, c.primaryColor.withOpacity(0.6)])),
        child: SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(c.playerEmoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 8),
            Text(c.displayName.toUpperCase(), textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(c.tagline, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
              child: Text('🏆 $playerName — Best: $highScore',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            _btn(context, '▶  PLAY', c.accentColor, Colors.black, _play),
            _btn(context, '❓  HOW TO PLAY', Colors.white24, Colors.white,
                () => _howTo(context, c)),
            _btn(context, '⚙️  SETTINGS', Colors.white24, Colors.white, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SettingsScreen(config: c))).then((_) => _load());
            }),
            _btn(context, '💛  SUPPORT', Colors.amber.shade700, Colors.black, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SupportScreen(config: c)));
            }),
            const SizedBox(height: 24),
            const Text('Credits: WAJIHA', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ])))),
      ),
    );
  }

  void _howTo(BuildContext ctx, ArcadeConfig c) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: c.darkColor,
      title: Text(c.displayName, style: const TextStyle(color: Colors.white)),
      content: Text(c.howTo, style: const TextStyle(color: Colors.white70)),
      actions: [TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text('GOT IT', style: TextStyle(color: c.accentColor)))],
    ));
  }

  Widget _btn(BuildContext ctx, String label, Color bg, Color fg, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: SizedBox(width: double.infinity, child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: fg,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      onPressed: onTap, child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
  );
}
