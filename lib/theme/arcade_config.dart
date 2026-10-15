import 'package:flutter/material.dart';

enum ArcadeMode {
  dodge, jump, catch_, breakout, flip, sling, stack, glide,
  pinball, maze, spin, rhythm, balance,
}

class ArcTheme {
  final String name;
  final int primary, dark, accent;
  const ArcTheme(this.name, this.primary, this.dark, this.accent);
}

// 12 built-in selectable themes (rich physical colors, no neon)
const List<ArcTheme> arcThemes = [
  ArcTheme('Ember Clay', 0xFFB5542D, 0xFF1D100B, 0xFFFFC46B),
  ArcTheme('Deep Lagoon', 0xFF1F7A8C, 0xFF081418, 0xFF7FE7DC),
  ArcTheme('Forest Moss', 0xFF4E7A3A, 0xFF0D150A, 0xFFD7E98B),
  ArcTheme('Royal Plum', 0xFF6C4A8A, 0xFF140F1C, 0xFFE0B3FF),
  ArcTheme('Desert Sand', 0xFFC99A5B, 0xFF1B140C, 0xFFFFE3A3),
  ArcTheme('Slate Harbor', 0xFF4A6572, 0xFF0C1216, 0xFFA8D8EA),
  ArcTheme('Cherry Wood', 0xFF8A3B3B, 0xFF170C0C, 0xFFFFB3A7),
  ArcTheme('Mint Grove', 0xFF3E8E6E, 0xFF0A1511, 0xFFB8F0D0),
  ArcTheme('Golden Wheat', 0xFFB98A2F, 0xFF181106, 0xFFFFE08A),
  ArcTheme('Ocean Depth', 0xFF2D5FA3, 0xFF0A1220, 0xFF9CC8FF),
  ArcTheme('Rose Garden', 0xFFA34A6E, 0xFF190D13, 0xFFFFC2D9),
  ArcTheme('Stone Keep', 0xFF6E6E6E, 0xFF121212, 0xFFE8E8E8),
];

const List<String> arcShapes = ['●', '■', '★', '◆', '♥', '⬤'];
const List<String> arcShapeNames = ['Orb', 'Cube', 'Star', 'Gem', 'Heart', 'Blob'];
const List<String> arcDifficulties = ['Chill', 'Normal', 'Turbo'];

class ArcadeConfig {
  final String slug, displayName, tagline;
  final int primary, dark, accent;
  final String playerEmoji, obstacleEmoji, collectEmoji, bgEmoji;
  final String howTo;
  final ArcadeMode mode;
  final double baseSpeed;
  final bool fallDown; // for jump mode: drop-through variant
  final String tip1Id, tip2Id, tip1Label, tip2Label;
  const ArcadeConfig({
    required this.slug,
    required this.displayName,
    required this.tagline,
    required this.primary,
    required this.dark,
    required this.accent,
    required this.playerEmoji,
    required this.obstacleEmoji,
    required this.collectEmoji,
    required this.bgEmoji,
    required this.howTo,
    required this.mode,
    this.baseSpeed = 1.0,
    this.fallDown = false,
    required this.tip1Id,
    required this.tip2Id,
    required this.tip1Label,
    required this.tip2Label,
  });
  Color get primaryColor => Color(primary);
  Color get darkColor => Color(dark);
  Color get accentColor => Color(accent);
  String get package => 'com.gameswajiha.$slug';
}

const arcadeConfig = ArcadeConfig(
  slug: 'zoomzapzone',
  displayName: 'Zoom Zap Zone',
  tagline: 'dodge and zap in neon lanes',
  primary: 0xFFC99A5B,
  dark: 0xFF1B140C,
  accent: 0xFFFFE3A3,
  playerEmoji: '🏎️',
  obstacleEmoji: '⚡',
  collectEmoji: '🔋',
  bgEmoji: '🌃',
  howTo: 'Drag or tap the sides to steer your Zoom Zap Zone. Dodge every ⚡s — one hit costs a life! Grab 🔋s for points and combo multipliers. Survive to level up; it gets faster!',
  mode: ArcadeMode.dodge,
  baseSpeed: 0.98,
  fallDown: false,
  tip1Id: 'zoomzapzonepretzel',
  tip2Id: 'zoomzapzoneburger',
  tip1Label: '💛 Buy me a pretzel for Zoom Zap Zone',

  tip2Label: '💛 Buy me a burger for Zoom Zap Zone',

);
