import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../theme/arcade_config.dart';

/// Generic gameplay entity. Normalized coords: x,y in 0..1, r in x-units.
class ArcBody {
  double x, y, vx, vy, r, w;
  int kind; // 0 obstacle, 1 collect, 2 brick, 3 platform, 4 target, 5 note, 6 bumper
  int hp;
  double t; // age in seconds
  double a; // extra angle / phase
  ArcBody({
    required this.x, required this.y,
    this.vx = 0, this.vy = 0, this.r = 0.04,
    this.kind = 0, this.hp = 1, this.w = 0.2, this.t = 0, this.a = 0,
  });
}

class ArcFX {
  double x, y, t;
  int kind; // 0 pop, 1 ring
  ArcFX(this.x, this.y, {this.kind = 0}) : t = 0;
}

/// One flexible engine driving 13 genuinely different arcade mechanics.
/// Player input always drives real simulation state — nothing decorative.
class ArcadeEngine extends ChangeNotifier {
  final ArcadeConfig cfg;
  final double diffMul; // difficulty: 0.8 chill, 1.0 normal, 1.3 turbo
  final Random _r = Random();

  // ---- common state ----
  int score = 0, combo = 0, bestCombo = 0, level = 1, lives = 3;
  bool playing = false, gameOver = false, paused = false;
  double time = 0, spawnT = 0;
  int invuln = 0; // ticks of mercy invulnerability after a hit
  int _scoredThisLevel = 0;
  int misses = 0;
  VoidCallback? onLevelUp;
  VoidCallback? onScore; // sound hook
  VoidCallback? onHit; // sound hook
  VoidCallback? onJump; // sound hook

  List<ArcBody> obs = [];
  List<ArcBody> cols = [];
  List<ArcBody> misc = []; // platforms, bricks, bumpers, notes, targets
  List<ArcFX> fx = [];

  // ---- player ----
  double px = 0.5, py = 0.8, pvx = 0, pvy = 0;
  final double pr = 0.045;

  // ---- mode-specific ----
  // breakout / pinball ball
  double bx = 0.5, by = 0.6, bvx = 0.3, bvy = -0.5;
  bool ballHeld = true;
  // jump
  bool grounded = false;
  // flip
  int gravDir = 1; // 1 floor, -1 ceiling
  // sling
  bool aiming = false;
  double aimX = 0, aimY = 0, coolT = 0;
  // stack
  double stackX = 0.5, stackDir = 1, towerTopY = 0.9, towerW = 0.34, towerX = 0.5;
  bool dropping = false;
  double dropY = 0.15, dropVy = 0;
  int towerH = 0;
  // glide walls
  // maze
  List<List<int>> maze = [];
  int mazeN = 9, mazeM = 13;
  double goalX = 0, goalY = 0;
  double mazeTime = 0;
  // spin
  int ringIdx = 0;
  double ringAngle = 0;
  List<double> ringSpeeds = [0.9, -0.7, 0.55];
  List<double> ringGaps = [0.6, 2.2, 4.0];
  // rhythm
  int rhythmBeat = 0;
  // balance
  double beamA = 0, beamAV = 0, gustT = 0, gustF = 0;
  // pinball flippers
  int flipSide = 0; // -1 left, 1 right, set on tap, decays
  double flipT = 0;

  Timer? _loop;

  ArcadeEngine({required this.cfg, this.diffMul = 1.0});

  double get speed => cfg.baseSpeed * diffMul * (1 + (level - 1) * 0.12);

  void start() {
    score = 0; combo = 0; bestCombo = 0; level = 1; lives = 3;
    time = 0; spawnT = 0.5; invuln = 0; misses = 0; _scoredThisLevel = 0;
    obs.clear(); cols.clear(); misc.clear(); fx.clear();
    playing = true; gameOver = false; paused = false;
    px = 0.5; py = 0.8; pvx = 0; pvy = 0;
    bx = 0.5; by = 0.62; bvx = 0.32; bvy = -0.5; ballHeld = true;
    grounded = false; gravDir = 1;
    aiming = false; coolT = 0;
    stackX = 0.5; stackDir = 1; towerTopY = 0.92; towerW = 0.36; towerX = 0.5;
    dropping = false; towerH = 0;
    ringIdx = 0; ringAngle = 0;
    beamA = 0; beamAV = 0; gustT = 2; gustF = 0;
    flipSide = 0; flipT = 0;
    _setupMode();
    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick(0.033));
    notifyListeners();
  }

  void stop() { _loop?.cancel(); playing = false; notifyListeners(); }
  void togglePause() {
    if (!playing || gameOver) return;
    paused = !paused;
    notifyListeners();
  }

  void _setupMode() {
    switch (cfg.mode) {
      case ArcadeMode.jump:
        if (!cfg.fallDown) {
          for (int i = 0; i < 6; i++) {
            misc.add(ArcBody(x: 0.1 + _r.nextDouble() * 0.7, y: 0.85 - i * 0.16,
                kind: 3, w: 0.22 + _r.nextDouble() * 0.1));
          }
          final p0 = misc.first;
          px = p0.x; py = p0.y - 0.02; grounded = true;
        } else {
          py = 0.1; pvy = 0.12;
        }
        break;
      case ArcadeMode.breakout:
        _buildBricks();
        break;
      case ArcadeMode.pinball:
        _buildBumpers();
        by = 0.15; bvy = 0.4; ballHeld = false;
        break;
      case ArcadeMode.maze:
        _buildMaze();
        break;
      case ArcadeMode.stack:
        break;
      default:
        break;
    }
  }

  // ================= TICK =================
  void _tick(double dt) {
    if (!playing || paused || gameOver) return;
    time += dt;
    if (invuln > 0) invuln--;
    if (coolT > 0) coolT -= dt;
    if (flipT > 0) { flipT -= dt; if (flipT <= 0) flipSide = 0; }
    for (final f in fx) f.t += dt;
    fx.removeWhere((f) => f.t > 0.4);
    for (final b in obs) b.t += dt;
    for (final b in cols) b.t += dt;
    for (final b in misc) b.t += dt;
    switch (cfg.mode) {
      case ArcadeMode.dodge: _tickDodge(dt); break;
      case ArcadeMode.jump: _tickJump(dt); break;
      case ArcadeMode.catch_: _tickCatch(dt); break;
      case ArcadeMode.breakout: _tickBreakout(dt); break;
      case ArcadeMode.flip: _tickFlip(dt); break;
      case ArcadeMode.sling: _tickSling(dt); break;
      case ArcadeMode.stack: _tickStack(dt); break;
      case ArcadeMode.glide: _tickGlide(dt); break;
      case ArcadeMode.pinball: _tickPinball(dt); break;
      case ArcadeMode.maze: _tickMaze(dt); break;
      case ArcadeMode.spin: _tickSpin(dt); break;
      case ArcadeMode.rhythm: _tickRhythm(dt); break;
      case ArcadeMode.balance: _tickBalance(dt); break;
    }
    notifyListeners();
  }

  void _levelUp() {
    _scoredThisLevel = 0;
    level++;
    onLevelUp?.call();
  }

  void _addScore(int base) {
    combo++;
    bestCombo = max(bestCombo, combo);
    score += (base * (1 + combo ~/ 4));
    _scoredThisLevel++;
    onScore?.call();
    if (_scoredThisLevel >= 12) _levelUp();
  }

  void _hurt() {
    if (invuln > 0) return;
    combo = 0;
    lives--;
    invuln = 45;
    onHit?.call();
    if (lives <= 0) _end();
  }

  void _end() {
    gameOver = true; playing = false;
    _loop?.cancel();
    notifyListeners();
  }

  double _dist(double x1, double y1, double x2, double y2) =>
      sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));

  // ================= DODGE =================
  void _tickDodge(double dt) {
    final sp = speed;
    spawnT -= dt;
    if (spawnT <= 0) {
      spawnT = max(0.32, 0.85 - level * 0.045) / diffMul;
      final roll = _r.nextDouble();
      if (roll < 0.62) {
        obs.add(ArcBody(x: 0.06 + _r.nextDouble() * 0.88, y: -0.06,
            vy: (0.32 + _r.nextDouble() * 0.22) * sp, r: 0.032 + _r.nextDouble() * 0.02,
            vx: (_r.nextDouble() - 0.5) * 0.12 * sp));
      } else {
        cols.add(ArcBody(x: 0.06 + _r.nextDouble() * 0.88, y: -0.06, kind: 1,
            vy: 0.3 * sp, r: 0.03));
      }
    }
    for (final o in obs) { o.x += o.vx * dt; o.y += o.vy * dt; }
    for (final c in cols) { c.y += c.vy * dt; }
    obs.removeWhere((o) => o.y > 1.12);
    cols.removeWhere((c) => c.y > 1.12);
    for (final o in List<ArcBody>.from(obs)) {
      if (_dist(px, py, o.x, o.y) < pr + o.r) { obs.remove(o); _hurt(); fx.add(ArcFX(px, py, kind: 1)); }
    }
    for (final c in List<ArcBody>.from(cols)) {
      if (_dist(px, py, c.x, c.y) < pr + c.r) {
        cols.remove(c); _addScore(10); fx.add(ArcFX(c.x, c.y));
      }
    }
  }

  // ================= JUMP =================
  void _tickJump(double dt) {
    const g = 2.4;
    if (cfg.fallDown) {
      // drop-through variant: steer X while falling, tap hops up a little
      pvy += g * 0.55 * dt;
      py += pvy * dt;
      px += pvx * dt;
      px = px.clamp(0.05, 0.95);
      if (py > 1.05) { py = 0.08; pvy = 0.1; _hurt(); }
      if (py < 0.02) { py = 0.02; pvy = 0; }
      spawnT -= dt;
      if (spawnT <= 0) {
        spawnT = max(0.5, 1.15 - level * 0.05) / diffMul;
        final gapX = 0.15 + _r.nextDouble() * 0.7;
        final gapW = max(0.16, 0.3 - level * 0.012);
        misc.add(ArcBody(x: 0, y: 1.06, kind: 3, w: 1.0, a: gapX - gapW / 2, t: gapX + gapW / 2, vy: -0.22 * speed));
        if (_r.nextDouble() < 0.5) {
          cols.add(ArcBody(x: gapX, y: 1.06, kind: 1, r: 0.028, vy: -0.22 * speed));
        }
      }
      for (final m in misc) m.y += m.vy * dt;
      for (final c in cols) c.y += c.vy * dt;
      misc.removeWhere((m) => m.y < -0.08);
      cols.removeWhere((c) => c.y < -0.08);
      for (final m in misc) {
        final inGap = px > m.a && px < m.t;
        if (!inGap && (py + pr) > m.y - 0.015 && (py - pr) < m.y + 0.015) {
          _hurt(); py = 0.08; pvy = 0.1; px = 0.5; break;
        }
        if (inGap && (py - pr) < m.y && (py + pr) > m.y) _addScore(5);
      }
      for (final c in List<ArcBody>.from(cols)) {
        if (_dist(px, py, c.x, c.y) < pr + c.r) { cols.remove(c); _addScore(10); fx.add(ArcFX(c.x, c.y)); }
      }
      return;
    }
    // classic climber
    pvy -= g * dt;
    py += pvy * dt;
    px += pvx * dt;
    px = px.clamp(0.04, 0.96);
    if (px <= 0.04 || px >= 0.96) pvx = 0;
    grounded = false;
    for (final p in misc) {
      if (pvy <= 0 && (py + pr) >= p.y - 0.012 && (py + pr) <= p.y + 0.05 &&
          (px - pr * 0.7).abs() < 1 && px > p.x - p.w / 2 - pr * 0.5 && px < p.x + p.w / 2 + pr * 0.5) {
        py = p.y - pr; pvy = 0; grounded = true;
      }
    }
    // camera scroll
    if (py < 0.45) {
      final dy = 0.45 - py;
      py = 0.45;
      for (final p in misc) p.y += dy;
      for (final c in cols) c.y += dy;
      score += (dy * 60).round();
    }
    // recycle platforms, spawn above
    misc.removeWhere((p) => p.y > 1.08);
    while (misc.length < 7) {
      final top = misc.map((p) => p.y).reduce(min);
      final np = ArcBody(x: 0.08 + _r.nextDouble() * 0.84, y: top - 0.15 - _r.nextDouble() * 0.08,
          kind: 3, w: max(0.14, 0.26 - level * 0.008));
      misc.add(np);
      if (_r.nextDouble() < 0.55) {
        cols.add(ArcBody(x: np.x, y: np.y - 0.07, kind: 1, r: 0.028));
      }
    }
    for (final c in cols) {
      if (c.y > 1.1) continue;
    }
    cols.removeWhere((c) => c.y > 1.12);
    for (final c in List<ArcBody>.from(cols)) {
      if (_dist(px, py, c.x, c.y) < pr + c.r + 0.02) {
        cols.remove(c); _addScore(10); fx.add(ArcFX(c.x, c.y));
      }
    }
    if (py > 1.1) {
      // fell: lose a life, respawn on lowest platform
      lives--; combo = 0; onHit?.call();
      if (lives <= 0) { _end(); return; }
      invuln = 45;
      final low = misc.map((p) => p.y).reduce(max);
      final lp = misc.firstWhere((p) => p.y == low);
      px = lp.x; py = lp.y - pr; pvy = 0; pvx = 0;
    }
  }

  void jumpTap() {
    if (cfg.mode != ArcadeMode.jump || !playing || paused || gameOver) return;
    if (cfg.fallDown) {
      pvy = -0.55; onJump?.call(); return;
    }
    if (grounded) { pvy = 0.95; grounded = false; onJump?.call(); }
  }

  // ================= CATCH =================
  void _tickCatch(double dt) {
    final sp = speed;
    spawnT -= dt;
    if (spawnT <= 0) {
      spawnT = max(0.3, 0.8 - level * 0.04) / diffMul;
      final roll = _r.nextDouble();
      final kind = roll < 0.6 ? 1 : roll < 0.85 ? 0 : 4;
      cols.add(ArcBody(x: 0.06 + _r.nextDouble() * 0.88, y: -0.05, kind: kind,
          vy: (kind == 4 ? 0.42 : 0.3 + _r.nextDouble() * 0.14) * sp, r: 0.032));
    }
    for (final c in cols) c.y += c.vy * dt;
    for (final c in List<ArcBody>.from(cols)) {
      if (c.y > 1.1) {
        if (c.kind == 1) { combo = 0; } // missed a good one
        cols.remove(c); continue;
      }
      if ((c.y + c.r) >= 0.82 && (c.y - c.r) <= 0.9 && (px - c.x).abs() < 0.09) {
        cols.remove(c);
        if (c.kind == 1) { _addScore(10); fx.add(ArcFX(c.x, c.y)); }
        else if (c.kind == 4) { _addScore(50); fx.add(ArcFX(c.x, c.y)); }
        else { _hurt(); fx.add(ArcFX(c.x, c.y, kind: 1)); }
      }
    }
  }

  // ================= BREAKOUT =================
  void _buildBricks() {
    misc.clear();
    final rows = 4 + (level ~/ 2);
    for (int r = 0; r < rows && r < 7; r++) {
      for (int cix = 0; cix < 7; cix++) {
        misc.add(ArcBody(
          x: 0.075 + cix * 0.142, y: 0.12 + r * 0.07,
          kind: 2, hp: (r == 0 && level > 2) ? 2 : 1, w: 0.13));
      }
    }
  }

  void _tickBreakout(double dt) {
    final sp = speed;
    if (ballHeld) { bx = px; by = 0.84; }
    else {
      bx += bvx * sp * dt; by += bvy * sp * dt;
      if (bx < 0.03) { bx = 0.03; bvx = bvx.abs(); }
      if (bx > 0.97) { bx = 0.97; bvx = -bvx.abs(); }
      if (by < 0.03) { by = 0.03; bvy = bvy.abs(); }
      // paddle
      if (bvy > 0 && by > 0.86 && by < 0.94 && (bx - px).abs() < 0.13) {
        by = 0.86; bvy = -bvy.abs();
        bvx += (bx - px) * 2.2;
        final m = sqrt(bvx * bvx + bvy * bvy);
        bvx = bvx / m * 0.62; bvy = bvy / m * 0.62;
        onJump?.call();
      }
      // bricks
      for (final br in List<ArcBody>.from(misc)) {
        if ((bx - br.x).abs() < br.w / 2 + 0.02 && (by - br.y).abs() < 0.045) {
          br.hp--;
          bvy = -bvy;
          if (br.hp <= 0) {
            misc.remove(br); _addScore(20); fx.add(ArcFX(br.x, br.y));
            if (misc.isEmpty) { _buildBricks(); _levelUp(); }
          } else { onHit?.call(); }
          break;
        }
      }
      if (by > 1.06) {
        lives--; combo = 0; onHit?.call();
        if (lives <= 0) { _end(); return; }
        ballHeld = true;
      }
    }
  }

  void launchBall() {
    if (cfg.mode == ArcadeMode.breakout && ballHeld && playing && !paused && !gameOver) {
      ballHeld = false;
      bvx = (_r.nextDouble() - 0.5) * 0.7; bvy = -0.62;
      final m = sqrt(bvx * bvx + bvy * bvy);
      bvx /= m / 0.62; bvy /= m / 0.62;
    }
  }

  // ================= FLIP =================
  void _tickFlip(double dt) {
    final sp = speed;
    final surface = gravDir == 1 ? 0.84 : 0.16;
    py += (surface - py) * min(1, dt * 10);
    spawnT -= dt;
    if (spawnT <= 0) {
      spawnT = max(0.4, 0.95 - level * 0.05) / diffMul;
      final onFloor = _r.nextBool();
      final roll = _r.nextDouble();
      if (roll < 0.68) {
        obs.add(ArcBody(x: 1.06, y: onFloor ? 0.84 : 0.16, vx: -0.42 * sp, r: 0.04));
      } else {
        cols.add(ArcBody(x: 1.06, y: onFloor ? 0.6 : 0.4, kind: 1, vx: -0.42 * sp, r: 0.03));
      }
    }
    for (final o in obs) o.x += o.vx * dt;
    for (final c in cols) c.x += c.vx * dt;
    obs.removeWhere((o) => o.x < -0.08);
    cols.removeWhere((c) => c.x < -0.08);
    for (final o in List<ArcBody>.from(obs)) {
      if (_dist(0.3, py, o.x, o.y) < pr + o.r) { obs.remove(o); _hurt(); fx.add(ArcFX(0.3, py, kind: 1)); }
    }
    for (final c in List<ArcBody>.from(cols)) {
      if (_dist(0.3, py, c.x, c.y) < pr + c.r + 0.03) {
        cols.remove(c); _addScore(10); fx.add(ArcFX(c.x, c.y));
      }
    }
  }

  void flipGravity() {
    if (cfg.mode != ArcadeMode.flip || !playing || paused || gameOver) return;
    gravDir = -gravDir;
    onJump?.call();
  }

  // ================= SLING =================
  void _tickSling(double dt) {
    final sp = speed;
    if (coolT <= 0 && misc.where((m) => m.kind == 4).length < 3 + level) {
      spawnT -= dt;
      if (spawnT <= 0) {
        spawnT = max(0.5, 1.2 - level * 0.06) / diffMul;
        misc.add(ArcBody(x: 0.45 + _r.nextDouble() * 0.5, y: 0.12 + _r.nextDouble() * 0.4,
            kind: 4, r: 0.04, vx: (_r.nextDouble() - 0.5) * 0.1 * sp,
            vy: (_r.nextDouble() - 0.5) * 0.08 * sp));
      }
    }
    for (final m in misc) {
      if (m.kind == 4) { m.x += m.vx * dt; m.y += m.vy * dt; }
      else { // projectile
        m.vy += 1.1 * dt; m.x += m.vx * dt; m.y += m.vy * dt;
      }
    }
    // projectile vs targets
    for (final p in List<ArcBody>.from(misc.where((m) => m.kind == 7))) {
      bool hit = false;
      for (final t in List<ArcBody>.from(misc.where((m) => m.kind == 4))) {
        if (_dist(p.x, p.y, t.x, t.y) < p.r + t.r) {
          misc.remove(t); hit = true;
          _addScore(25); fx.add(ArcFX(t.x, t.y));
          break;
        }
      }
      if (hit || p.x > 1.1 || p.y > 1.1 || p.x < -0.1) {
        if (!hit) combo = 0;
        misc.remove(p);
      }
    }
    misc.removeWhere((m) => m.kind == 4 && (m.x < -0.1 || m.x > 1.1 || m.y < -0.1 || m.y > 1.1));
  }

  void slingAim(double x, double y) {
    if (cfg.mode != ArcadeMode.sling || !playing || paused || gameOver) return;
    aiming = true; aimX = x; aimY = y;
  }

  void slingRelease() {
    if (cfg.mode != ArcadeMode.sling || !aiming || !playing || paused || gameOver) return;
    aiming = false;
    if (coolT > 0) return;
    coolT = 0.35;
    double dx = 0.15 - aimX, dy = 0.85 - aimY;
    final m = max(0.15, sqrt(dx * dx + dy * dy));
    dx /= m; dy /= m;
    misc.add(ArcBody(x: 0.15, y: 0.85, vx: dx * 1.15, vy: dy * 1.15 - 0.25, r: 0.032, kind: 7));
    onJump?.call();
  }

  // ================= STACK =================
  void _tickStack(double dt) {
    final sp = speed;
    if (!dropping) {
      stackX += stackDir * 0.5 * sp * dt;
      if (stackX > 0.85) { stackX = 0.85; stackDir = -1; }
      if (stackX < 0.15) { stackX = 0.15; stackDir = 1; }
    } else {
      dropVy += 2.6 * dt;
      dropY += dropVy * dt;
      if (dropY >= towerTopY - 0.035) {
        dropping = false;
        final dx = (stackX - towerX).abs();
        if (dx >= towerW) {
          // total miss
          _hurt();
        } else {
          final perfect = dx < 0.02;
          towerW = towerW - dx;
          towerX = (stackX + towerX) / 2 + (stackX > towerX ? -dx / 4 : dx / 4);
          towerX = (min(stackX, towerX) + max(stackX, towerX)) / 2;
          towerTopY -= 0.07;
          towerH++;
          if (perfect) { _addScore(50); fx.add(ArcFX(stackX, towerTopY, kind: 1)); }
          else { _addScore(10); }
          if (towerTopY < 0.3) {
            // shift view down, keep building
            towerTopY = 0.85;
          }
        }
        dropY = 0.15; dropVy = 0;
        stackX = 0.5;
      }
    }
  }

  void stackDrop() {
    if (cfg.mode != ArcadeMode.stack || dropping || !playing || paused || gameOver) return;
    dropping = true; dropY = 0.15; dropVy = 0;
    onJump?.call();
  }

  // ================= GLIDE =================
  void _tickGlide(double dt) {
    final sp = speed;
    // vertical control via hold flag stored in pvx (1 = holding)
    pvy = pvx > 0.5 ? -0.52 : 0.5;
    py += pvy * dt * sp;
    py = py.clamp(0.06, 0.94);
    spawnT -= dt;
    if (spawnT <= 0) {
      spawnT = max(0.7, 1.5 - level * 0.07) / diffMul;
      final gapY = 0.2 + _r.nextDouble() * 0.6;
      final gapH = max(0.24, 0.36 - level * 0.012);
      obs.add(ArcBody(x: 1.06, y: gapY, vx: -0.4 * sp, kind: 0, w: 0.09, a: gapH, r: 0.045));
      if (_r.nextDouble() < 0.6) {
        cols.add(ArcBody(x: 1.12, y: gapY, kind: 1, vx: -0.4 * sp, r: 0.028));
      }
    }
    for (final o in obs) o.x += o.vx * dt;
    for (final c in cols) c.x += c.vx * dt;
    obs.removeWhere((o) => o.x < -0.1);
    cols.removeWhere((c) => c.x < -0.1);
    for (final o in List<ArcBody>.from(obs)) {
      final inX = (0.3 - o.x).abs() < o.w / 2 + pr;
      final inGap = (py - o.y).abs() < o.a / 2;
      if (inX && !inGap) {
        obs.remove(o); _hurt(); fx.add(ArcFX(0.3, py, kind: 1));
      } else if (inX && inGap && o.t > 0 && (o.x - 0.3).abs() < 0.03) {
        _addScore(10);
      }
    }
    for (final c in List<ArcBody>.from(cols)) {
      if (_dist(0.3, py, c.x, c.y) < pr + c.r + 0.02) {
        cols.remove(c); _addScore(10); fx.add(ArcFX(c.x, c.y));
      }
    }
  }

  void glideHold(bool h) {
    if (cfg.mode != ArcadeMode.glide || !playing || paused || gameOver) return;
    pvx = h ? 1 : 0;
  }

  // ================= PINBALL =================
  void _buildBumpers() {
    misc.clear();
    final spots = [
      [0.25, 0.3], [0.5, 0.22], [0.75, 0.3], [0.35, 0.5], [0.65, 0.5], [0.5, 0.68],
    ];
    for (final s in spots) {
      misc.add(ArcBody(x: s[0], y: s[1], kind: 6, r: 0.055));
    }
  }

  void _tickPinball(double dt) {
    final sp = speed;
    bvy += 0.55 * dt;
    bx += bvx * sp * dt; by += bvy * sp * dt;
    if (bx < 0.04) { bx = 0.04; bvx = bvx.abs() * 0.96; }
    if (bx > 0.96) { bx = 0.96; bvx = -bvx.abs() * 0.96; }
    if (by < 0.04) { by = 0.04; bvy = bvy.abs() * 0.96; }
    // bumpers
    for (final b in misc) {
      final d = _dist(bx, by, b.x, b.y);
      if (d < b.r + 0.035 && d > 0.0001) {
        final nx = (bx - b.x) / d, ny = (by - b.y) / d;
        final dot = bvx * nx + bvy * ny;
        bvx = (bvx - 2 * dot * nx) * 0.98;
        bvy = (bvy - 2 * dot * ny) * 0.98;
        final m = sqrt(bvx * bvx + bvy * bvy);
        if (m < 0.45) { bvx = bvx / m * 0.45; bvy = bvy / m * 0.45; }
        bx = b.x + nx * (b.r + 0.036);
        by = b.y + ny * (b.r + 0.036);
        _addScore(15); fx.add(ArcFX(b.x, b.y));
      }
    }
    // flippers near bottom
    if (flipSide != 0 && flipT > 0.25) {
      final fx0 = flipSide < 0 ? 0.32 : 0.68;
      if ((bx - fx0).abs() < 0.14 && by > 0.78 && by < 0.95 && bvy > 0) {
        bvy = -0.95; bvx += flipSide * 0.25;
        flipT = 0; onJump?.call();
      }
    }
    if (by > 1.06) {
      lives--; combo = 0; onHit?.call();
      if (lives <= 0) { _end(); return; }
      bx = 0.5; by = 0.15; bvx = 0.2; bvy = 0.35;
    }
  }

  void pinballFlip(int side) {
    if (cfg.mode != ArcadeMode.pinball || !playing || paused || gameOver) return;
    flipSide = side; flipT = 0.35;
  }

  // ================= MAZE =================
  void _buildMaze() {
    maze = List.generate(mazeM, (_) => List.filled(mazeN, 1));
    final stack = <List<int>>[];
    var cx = 0, cy = 0;
    maze[cy][cx] = 0;
    stack.add([cx, cy]);
    final dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    while (stack.isNotEmpty) {
      final top = stack.last; cx = top[0]; cy = top[1];
      final opts = <List<int>>[];
      for (final d in dirs) {
        final nx = cx + d[0] * 2, ny = cy + d[1] * 2;
        if (nx >= 0 && nx < mazeN && ny >= 0 && ny < mazeM && maze[ny][nx] == 1) {
          opts.add(d);
        }
      }
      if (opts.isEmpty) { stack.removeLast(); continue; }
      final d = opts[_r.nextInt(opts.length)];
      maze[cy + d[1]][cx + d[0]] = 0;
      maze[cy + d[1] * 2][cx + d[0] * 2] = 0;
      stack.add([cx + d[0] * 2, cy + d[1] * 2]);
    }
    // start top-left, goal bottom-right
    px = 0.5 / mazeN; py = 0.08 + 0.5 / mazeM;
    goalX = (mazeN - 0.5) / mazeN; goalY = 0.08 + (mazeM - 0.5) / mazeM;
    pvx = 0; pvy = 0; mazeTime = 0;
    // a few collectibles on open cells
    cols.clear();
    for (int i = 0; i < 6; i++) {
      final gx = _r.nextInt(mazeN), gy = _r.nextInt(mazeM);
      if (maze[gy][gx] == 0) {
        cols.add(ArcBody(x: (gx + 0.5) / mazeN, y: 0.08 + (gy + 0.5) / mazeM, kind: 1, r: 0.025));
      }
    }
  }

  bool _mazeWall(double x, double y) {
    final gx = (x * mazeN).floor().clamp(0, mazeN - 1);
    final gy = ((y - 0.08) * mazeM).floor().clamp(0, mazeM - 1);
    return maze[gy][gx] == 1;
  }

  void _tickMaze(double dt) {
    mazeTime += dt;
    // velocity set by drag input (pvx, pvy as target velocity)
    double nx = px + pvx * dt;
    double ny = py + pvy * dt;
    final rad = pr * 0.8;
    if (!_mazeWall(nx + rad * (pvx >= 0 ? 1 : -1), py) &&
        !_mazeWall(nx + rad * (pvx >= 0 ? 1 : -1), py + rad * 0.6) &&
        !_mazeWall(nx + rad * (pvx >= 0 ? 1 : -1), py - rad * 0.6)) {
      px = nx.clamp(0.02, 0.98);
    }
    if (!_mazeWall(px, ny + rad * (pvy >= 0 ? 1 : -1)) &&
        !_mazeWall(px + rad * 0.6, ny + rad * (pvy >= 0 ? 1 : -1)) &&
        !_mazeWall(px - rad * 0.6, ny + rad * (pvy >= 0 ? 1 : -1))) {
      py = ny.clamp(0.1, 0.98);
    }
    // friction
    pvx *= (1 - min(1, dt * 4));
    pvy *= (1 - min(1, dt * 4));
    for (final c in List<ArcBody>.from(cols)) {
      if (_dist(px, py, c.x, c.y) < pr + c.r) {
        cols.remove(c); _addScore(10); fx.add(ArcFX(c.x, c.y));
      }
    }
    if (_dist(px, py, goalX, goalY) < 0.06) {
      final bonus = max(0, 120 - mazeTime.round() * 2);
      score += 100 + bonus * level;
      _scoredThisLevel += 6;
      if (_scoredThisLevel >= 12) _levelUp(); else _scoredThisLevel = _scoredThisLevel;
      fx.add(ArcFX(goalX, goalY, kind: 1));
      onLevelUp?.call();
      _buildMaze();
    }
  }

  void mazeSteer(double dx, double dy) {
    if (cfg.mode != ArcadeMode.maze || !playing || paused || gameOver) return;
    pvx = dx.clamp(-1, 1) * 0.55;
    pvy = dy.clamp(-1, 1) * 0.55;
  }

  // ================= SPIN =================
  void _tickSpin(double dt) {
    final sp = speed;
    ringAngle += dt * 0.6 * sp;
    // player rides ring ringIdx
    final radii = [0.16, 0.28, 0.40];
    final rr = radii[ringIdx];
    final w = ringSpeeds[ringIdx] * sp;
    final gap = ringGaps[ringIdx];
    // player angle advances with ring
    misc.isEmpty ? null : null;
    // store player angle in pvx
    pvx += w * dt;
    px = 0.5 + cos(pvx) * rr;
    py = 0.5 + sin(pvx) * rr * 1.25;
    // gap check: gap center rotates with ringAngle
    double rel = (pvx - ringAngle * w.sign) % (2 * pi);
    if (rel < 0) rel += 2 * pi;
    double gapC = gap % (2 * pi);
    double gd = (rel - gapC).abs();
    if (gd < 0.28) {
      // over the gap -> fall
      _hurt();
      ringIdx = 0; pvx = 0;
      return;
    }
    spawnT -= dt;
    if (spawnT <= 0) {
      spawnT = max(0.6, 1.4 - level * 0.06) / diffMul;
      final gi = _r.nextInt(3);
      final ga = _r.nextDouble() * 2 * pi;
      cols.add(ArcBody(x: 0.5 + cos(ga) * radii[gi], y: 0.5 + sin(ga) * radii[gi] * 1.25,
          kind: 1, r: 0.028, a: gi.toDouble(), t: ga));
    }
    // gems ride their rings
    for (final c in cols) {
      final gr = radii[c.a.toInt().clamp(0, 2)];
      final gw = ringSpeeds[c.a.toInt().clamp(0, 2)] * sp;
      c.t += gw * dt;
      c.x = 0.5 + cos(c.t) * gr;
      c.y = 0.5 + sin(c.t) * gr * 1.25;
    }
    cols.removeWhere((c) => false);
    for (final c in List<ArcBody>.from(cols)) {
      if (_dist(px, py, c.x, c.y) < pr + c.r + 0.02) {
        cols.remove(c); _addScore(10); fx.add(ArcFX(c.x, c.y));
      }
    }
  }

  void spinHop() {
    if (cfg.mode != ArcadeMode.spin || !playing || paused || gameOver) return;
    ringIdx = (ringIdx + 1) % 3;
    onJump?.call();
  }

  // ================= RHYTHM =================
  void _tickRhythm(double dt) {
    final sp = speed;
    spawnT -= dt;
    if (spawnT <= 0) {
      spawnT = max(0.32, 0.62 - level * 0.025) / diffMul;
      final lane = _r.nextInt(3);
      misc.add(ArcBody(x: 0.2 + lane * 0.3, y: -0.05, kind: 5, vy: 0.55 * sp, r: 0.045, a: lane.toDouble()));
      rhythmBeat++;
    }
    for (final n in misc) n.y += n.vy * dt;
    for (final n in List<ArcBody>.from(misc)) {
      if (n.y > 1.05) {
        misc.remove(n);
        misses++;
        combo = 0;
        if (misses >= 8) { misses = 0; _hurt(); }
      }
    }
  }

  void rhythmTap(double x) {
    if (cfg.mode != ArcadeMode.rhythm || !playing || paused || gameOver) return;
    final lane = ((x - 0.05) / 0.3).floor().clamp(0, 2);
    ArcBody? best;
    double bestD = 1e9;
    for (final n in misc) {
      if (n.a.toInt() == lane) {
        final d = (n.y - 0.8).abs();
        if (d < bestD) { bestD = d; best = n; }
      }
    }
    if (best != null && bestD < 0.12) {
      misc.remove(best);
      if (bestD < 0.05) { _addScore(30); }
      else { _addScore(10); }
      fx.add(ArcFX(best.x, 0.8));
    } else {
      combo = 0;
      misses++;
      if (misses >= 8) { misses = 0; _hurt(); }
    }
  }

  // ================= BALANCE =================
  void _tickBalance(double dt) {
    final sp = speed;
    gustT -= dt;
    if (gustT <= 0) {
      gustT = 1.5 + _r.nextDouble() * 1.5;
      gustF = (_r.nextDouble() - 0.5) * 2.2 * sp;
    }
    // beam topples: angular accel proportional to angle + gusts
    beamAV += (beamA * 3.2 + gustF) * dt;
    beamAV *= (1 - min(1, dt * 1.2));
    beamA += beamAV * dt;
    // ball rolls along beam
    px += (beamA * 1.4) * dt;
    py = 0.55 - beamA * 0.4;
    score += (dt * 8).round();
    time += 0; // time already advanced
    if ((dt * 8) > 0 && (time * 8).round() % 60 == 0) { /* steady tick */ }
    if (beamA.abs() > 0.55 || px < 0.06 || px > 0.94) {
      _hurt();
      beamA = 0; beamAV = 0; px = 0.5; gustF = 0;
    }
    // survival scoring ticks
    _scoredThisLevel++;
    if (_scoredThisLevel >= 240) { _scoredThisLevel = 0; level++; onLevelUp?.call(); }
  }

  void balanceNudge(int dir) {
    if (cfg.mode != ArcadeMode.balance || !playing || paused || gameOver) return;
    beamAV += dir * 1.6;
    onJump?.call();
  }

  // ================= GENERIC INPUT =================
  /// Drag / swipe: meaning depends on mode.
  void onDrag(double x, double y, double dx, double dy) {
    if (!playing || paused || gameOver) return;
    switch (cfg.mode) {
      case ArcadeMode.dodge:
      case ArcadeMode.catch_:
        px = x.clamp(0.05, 0.95);
        break;
      case ArcadeMode.jump:
        px = x.clamp(0.04, 0.96);
        pvx = dx * 3;
        break;
      case ArcadeMode.breakout:
        px = x.clamp(0.12, 0.88);
        break;
      case ArcadeMode.maze:
        mazeSteer(dx * 4, dy * 4);
        break;
      case ArcadeMode.sling:
        slingAim(x, y);
        break;
      default:
        break;
    }
  }

  /// Tap: meaning depends on mode.
  void onTap(double x, double y) {
    if (!playing || paused || gameOver) return;
    switch (cfg.mode) {
      case ArcadeMode.dodge:
        px = (px + (x < 0.5 ? -0.14 : 0.14)).clamp(0.05, 0.95);
        break;
      case ArcadeMode.jump:
        jumpTap();
        break;
      case ArcadeMode.breakout:
        if (ballHeld) launchBall();
        else px = x.clamp(0.12, 0.88);
        break;
      case ArcadeMode.flip:
        flipGravity();
        break;
      case ArcadeMode.stack:
        stackDrop();
        break;
      case ArcadeMode.glide:
        break; // hold handled separately
      case ArcadeMode.pinball:
        pinballFlip(x < 0.5 ? -1 : 1);
        break;
      case ArcadeMode.spin:
        spinHop();
        break;
      case ArcadeMode.rhythm:
        rhythmTap(x);
        break;
      case ArcadeMode.balance:
        balanceNudge(x < 0.5 ? -1 : 1);
        break;
      case ArcadeMode.catch_:
        px = x.clamp(0.05, 0.95);
        break;
      case ArcadeMode.sling:
        break;
      case ArcadeMode.maze:
        break;
    }
  }

  void onHoldStart() => glideHold(true);
  void onHoldEnd() {
    glideHold(false);
    if (cfg.mode == ArcadeMode.sling) slingRelease();
  }

  @override
  void dispose() { _loop?.cancel(); super.dispose(); }
}
