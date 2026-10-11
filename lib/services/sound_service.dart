import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny synthesized SFX + music loop player. All assets are generated WAVs,
/// bundled offline. Respects music/sfx toggles stored per game prefix.
class SoundService {
  final String prefix;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  bool _musicOn = true, _sfxOn = true;
  bool _musicStarted = false;

  SoundService(this.prefix);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _musicOn = sp.getBool('${prefix}music') ?? true;
    _sfxOn = sp.getBool('${prefix}sfx') ?? true;
  }

  Future<void> refresh() => load();

  Future<void> startMusic() async {
    if (!_musicOn || _musicStarted) return;
    _musicStarted = true;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.play(AssetSource('sfx/music_loop.wav'));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    _musicStarted = false;
    try { await _music.stop(); } catch (_) {}
  }

  Future<void> _play(String file) async {
    if (!_sfxOn) return;
    try { await _sfx.play(AssetSource('sfx/$file')); } catch (_) {}
  }

  Future<void> click() => _play('click.wav');
  Future<void> good() => _play('good.wav');
  Future<void> bad() => _play('bad.wav');
  Future<void> jump() => _play('jump.wav');
  Future<void> level() => _play('level.wav');
  Future<void> win() => _play('win.wav');
  Future<void> lose() => _play('lose.wav');

  void dispose() {
    _sfx.dispose();
    _music.dispose();
  }
}
