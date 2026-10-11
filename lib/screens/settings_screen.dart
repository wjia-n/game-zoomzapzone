import 'package:flutter/material.dart';
import '../theme/arcade_config.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final ArcadeConfig config;
  const SettingsScreen({super.key, required this.config});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool music = true, sfx = true, vibration = true;
  String playerName = 'Player 1';
  int themeIdx = -1, shapeIdx = 0, diffIdx = 1;
  final _nameCtrl = TextEditingController();
  late SettingsService _svc;

  @override void initState() {
    super.initState();
    _svc = SettingsService('${widget.config.slug}_');
    _load();
  }

  Future<void> _load() async {
    music = await _svc.getMusic();
    sfx = await _svc.getSfx();
    vibration = await _svc.getVibration();
    playerName = await _svc.getPlayerName();
    themeIdx = await _svc.getTheme();
    shapeIdx = await _svc.getShape();
    diffIdx = await _svc.getDifficulty();
    _nameCtrl.text = playerName;
    if (mounted) setState(() {});
  }

  @override Widget build(BuildContext context) {
    final c = widget.config;
    final activeTheme = themeIdx >= 0 ? arcThemes[themeIdx % arcThemes.length] : null;
    return Scaffold(
      backgroundColor: c.darkColor,
      appBar: AppBar(title: const Text('Settings'), backgroundColor: c.primaryColor, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('PLAYER NAME', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(filled: true, fillColor: Colors.white10, hintText: 'Your name',
            hintStyle: const TextStyle(color: Colors.white30),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
          onChanged: (v) { playerName = v; _svc.setPlayerName(v); }),
        const SizedBox(height: 16),
        const Text('DIFFICULTY', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: List.generate(3, (i) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(arcDifficulties[i]),
            selected: diffIdx == i,
            selectedColor: c.accentColor,
            onSelected: (_) { setState(() => diffIdx = i); _svc.setDifficulty(i); },
          ))))),
        const SizedBox(height: 16),
        Row(children: [
          const Text('THEME', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const Spacer(),
          if (themeIdx >= 0) TextButton(
            onPressed: () { setState(() => themeIdx = -1); _svc.setTheme(-1); },
            child: const Text('Reset', style: TextStyle(color: Colors.white54))),
        ]),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.8),
          itemCount: arcThemes.length,
          itemBuilder: (_, i) {
            final t = arcThemes[i];
            final sel = themeIdx == i;
            return GestureDetector(
              onTap: () { setState(() => themeIdx = i); _svc.setTheme(i); },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 3),
                  gradient: LinearGradient(colors: [Color(t.dark), Color(t.primary)]),
                ),
                child: Center(child: Text(t.name.split(' ').first,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ),
            );
          }),
        const SizedBox(height: 16),
        const Text('PLAYER SHAPE', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Row(children: List.generate(arcShapes.length, (i) => Expanded(child: GestureDetector(
          onTap: () { setState(() => shapeIdx = i); _svc.setShape(i); },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: shapeIdx == i ? c.accentColor.withOpacity(0.35) : Colors.white10,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: shapeIdx == i ? c.accentColor : Colors.transparent, width: 2)),
            child: Center(child: Text(arcShapes[i],
                style: const TextStyle(color: Colors.white, fontSize: 22))),
          ))))),
        const SizedBox(height: 4),
        Center(child: Text(arcShapeNames[shapeIdx % arcShapeNames.length],
            style: const TextStyle(color: Colors.white54, fontSize: 12))),
        const SizedBox(height: 16),
        _toggle('🎵 Music', music, (v) { setState(() => music = v); _svc.setMusic(v); }),
        _toggle('🔊 Sound FX', sfx, (v) { setState(() => sfx = v); _svc.setSfx(v); }),
        _toggle('📳 Vibration', vibration, (v) { setState(() => vibration = v); _svc.setVibration(v); }),
        const SizedBox(height: 16),
        if (activeTheme != null)
          Text('Preview uses "${activeTheme.name}" in menus after restart.',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        Card(color: Colors.white10, child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HOW TO PLAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(c.howTo, style: const TextStyle(color: Colors.white70)),
        ]))),
      ]),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    title: Text(label, style: const TextStyle(color: Colors.white)),
    value: value, onChanged: onChanged, activeColor: widget.config.accentColor);
}
