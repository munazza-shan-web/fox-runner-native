import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

// ===== Fox Forest Runner: everything in ONE file =====
// Part 1: game rules   Part 2: drawing   Part 3: screen and buttons

// ---------- Part 1: game rules ----------
enum Phase { ready, play, over }

class Obstacle {
  double x;
  final double w, h;
  final bool rock;
  Obstacle(this.x, this.w, this.h, this.rock);
}

class Coin {
  double x, y;
  bool got = false;
  Coin(this.x, this.y);
}

class Puff {
  double x, y, r, a, vx, vy;
  Puff(this.x, this.y, this.r, this.a, this.vx, this.vy);
}

/// All game rules. The screen is a fixed 960 x 640 world scaled to fit.
class Game {
  static const double width = 960, height = 640, groundY = 440;

  // Tweak these to change how the game feels.
  static const double jumpSpeed = 840, gravity = 2300;
  static const double startSpeed = 360, maxSpeed = 680, accel = 8;

  final Random _rnd = Random();
  Phase phase = Phase.ready;
  bool paused = false, air = false;
  double dist = 0, speed = startSpeed, t = 0, foxY = 0, foxVy = 0;
  double nextSpawn = 700, overTimer = 0;
  int coins = 0, best = 0;
  final List<Obstacle> obstacles = [];
  final List<Coin> coinList = [];
  final List<Puff> puffs = [];

  int get score => (dist / 50).floor();

  double _r(double a, double b) => a + _rnd.nextDouble() * (b - a);

  void start() {
    phase = Phase.play;
    paused = false;
    dist = 0;
    coins = 0;
    speed = startSpeed;
    obstacles.clear();
    coinList.clear();
    puffs.clear();
    foxY = 0;
    nextSpawn = 700;
    foxVy = -jumpSpeed;
    air = true;
  }

  void jump() {
    if (phase == Phase.ready) {
      start();
    } else if (phase == Phase.over) {
      if (overTimer > .35) start();
    } else if (!paused && !air) {
      foxVy = -jumpSpeed;
      air = true;
    }
  }

  void togglePause() {
    if (phase == Phase.play) paused = !paused;
  }

  void _end() {
    phase = Phase.over;
    overTimer = 0;
    if (score > best) best = score;
  }

  void _puff() {
    puffs.add(Puff(170, groundY - 6, _r(6, 12), 1, _r(-70, -30), _r(-30, -10)));
  }

  void _spawn() {
    final rock = _rnd.nextDouble() < .4;
    final o = rock
        ? Obstacle(width + 60, 90, 70, true)
        : Obstacle(width + 60, 110, 80, false);
    obstacles.add(o);
    if (_rnd.nextDouble() < .75) {
      for (var i = 0; i < 3; i++) {
        coinList.add(Coin(o.x + o.w / 2 - 50 + i * 50,
            groundY - 190 + (i == 1 ? -18 : 0)));
      }
    }
    nextSpawn = _r(480, 780) + speed * .3;
  }

  void update(double dt) {
    t += dt;
    if (phase == Phase.over) overTimer += dt;
    if (phase != Phase.play) return;

    speed = min(maxSpeed, speed + dt * accel);
    dist += speed * dt;
    foxVy += gravity * dt;
    foxY += foxVy * dt;
    if (foxY >= 0) {
      if (air) {
        for (var i = 0; i < 5; i++) {
          _puff();
        }
      }
      foxY = 0;
      foxVy = 0;
      air = false;
    }
    if (!air && _rnd.nextDouble() < dt * 18) _puff();

    nextSpawn -= speed * dt;
    if (nextSpawn <= 0) _spawn();

    const fl = 170.0, fr = 235.0;
    final ft = groundY + foxY - 70, fb = groundY + foxY;
    var hit = false;
    for (final o in obstacles) {
      o.x -= speed * dt;
      if (fr > o.x + 8 &&
          fl < o.x + o.w - 8 &&
          fb > groundY - o.h + 8 &&
          ft < groundY) {
        hit = true;
      }
    }
    for (final c in coinList) {
      c.x -= speed * dt;
      if (!c.got &&
          (c.x - 210).abs() < 45 &&
          (c.y - (groundY + foxY - 45)).abs() < 55) {
        c.got = true;
        coins++;
      }
    }
    obstacles.removeWhere((o) => o.x < -150);
    coinList.removeWhere((c) => c.x < -50 || c.got);
    for (final p in puffs) {
      p.x += (p.vx - speed * .6) * dt;
      p.y += p.vy * dt;
      p.a -= dt * 1.8;
      p.r += dt * 14;
    }
    puffs.removeWhere((p) => p.a <= 0);
    if (hit) _end();
  }
}

// ---------- Part 2: drawing ----------
/// Draws the forest, ground, fox, logs, rocks and coins.
class ScenePainter extends CustomPainter {
  final Game g;
  ScenePainter(this.g, Listenable repaint) : super(repaint: repaint);

  static const double gy = Game.groundY;
  static final Random _r = Random(7);
  static final List<List<double>> pines = List.generate(
      16, (i) => [i * 90 + _r.nextDouble() * 40 - 20, 130 + _r.nextDouble() * 100]);
  static final List<List<double>> bushes = List.generate(
      10, (i) => [i * 150 + _r.nextDouble() * 60 - 30, 55 + _r.nextDouble() * 40]);
  static final List<List<double>> trunks = List.generate(
      3, (i) => [i * 520.0 + 120, 80 + _r.nextDouble() * 30]);
  static final List<List<double>> ferns = List.generate(
      14, (i) => [i * 120 + _r.nextDouble() * 60 - 30, 60 + _r.nextDouble() * 60]);

  final Paint _p = Paint();

  double _wrap(double px, double off, double span) => ((px - off) % span) - 150;

  void circ(Canvas c, double x, double y, double r, Color col) {
    _p
      ..style = PaintingStyle.fill
      ..color = col;
    c.drawCircle(Offset(x, y), r, _p);
  }

  void ov(Canvas c, double x, double y, double rx, double ry, Color col,
      [double rot = 0]) {
    _p
      ..style = PaintingStyle.fill
      ..color = col;
    c.save();
    c.translate(x, y);
    c.rotate(rot);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), _p);
    c.restore();
  }

  void box(Canvas c, double x, double y, double w, double h, Color col) {
    _p
      ..style = PaintingStyle.fill
      ..color = col;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _p);
  }

  void poly(Canvas c, List<double> v, Color col) {
    final path = Path()..moveTo(v[0], v[1]);
    for (var i = 2; i < v.length; i += 2) {
      path.lineTo(v[i], v[i + 1]);
    }
    path.close();
    _p
      ..style = PaintingStyle.fill
      ..color = col;
    c.drawPath(path, _p);
  }

  void line(Canvas c, double x1, double y1, double x2, double y2, Color col, double w) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w
      ..color = col;
    c.drawLine(Offset(x1, y1), Offset(x2, y2), _p);
    _p.style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / Game.width, size.height / Game.height);
    c.clipRect(const Rect.fromLTWH(0, 0, Game.width, Game.height));
    _background(c);
    _ground(c);
    for (final o in g.obstacles) {
      o.rock ? _rock(c, o) : _log(c, o);
    }
    for (final k in g.coinList) {
      _coin(c, k);
    }
    for (final p in g.puffs) {
      circ(c, p.x, p.y, p.r,
          Color.fromRGBO(246, 238, 221, p.a.clamp(0.0, 1.0).toDouble()));
    }
    _fox(c);
    _front(c);
    c.restore();
  }

  void _background(Canvas c) {
    _p.shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, gy),
        const [Color(0xFF69C4F0), Color(0xFFC8ECF2)]);
    c.drawRect(const Rect.fromLTWH(0, 0, Game.width, Game.height), _p);
    _p.shader = null;

    final cx = (500 - g.dist * .03) % 1100 - 150;
    circ(c, cx, 100, 34, Colors.white);
    circ(c, cx + 40, 88, 42, Colors.white);
    circ(c, cx + 85, 104, 30, Colors.white);

    for (final p in pines) {
      final px = _wrap(p[0], g.dist * .1, 1440);
      poly(c, [px, gy - p[1], px + 38, gy, px - 38, gy], const Color(0xFF5CB7A8));
    }
    for (final b in bushes) {
      final bx = _wrap(b[0], g.dist * .25, 1500);
      circ(c, bx, gy - b[1] * .4, b[1], const Color(0xFF7CC65C));
      circ(c, bx + b[1] * .6, gy - b[1] * .7, b[1] * .7, const Color(0xFF8FD468));
    }
    for (final t in trunks) {
      final tx = _wrap(t[0], g.dist * .45, 1560);
      box(c, tx - t[1] / 2, 150, t[1], gy - 150, const Color(0xFF8A5A30));
      box(c, tx - t[1] / 2, 150, t[1] * .3, gy - 150, const Color(0xFFA87040));
      circ(c, tx, 110, 110, const Color(0xFF4AA83C));
      circ(c, tx - 90, 170, 80, const Color(0xFF3F9A34));
      circ(c, tx + 90, 160, 85, const Color(0xFF5BBD48));
      circ(c, tx, 40, 80, const Color(0xFF69CC4F));
    }
  }

  void _ground(Canvas c) {
    box(c, 0, gy, Game.width, Game.height - gy, const Color(0xFFA8683A));
    for (var i = 0; i < 9; i++) {
      final sx = _wrap(i * 130.0 + 40, g.dist, 1170);
      ov(c, sx + 150, gy + 90 + (i % 3) * 45, 12, 7, const Color(0xFF8F5530));
    }
    box(c, 0, gy, Game.width, 26, const Color(0xFF5FC22E));
    for (var i = -1; i < Game.width / 22 + 2; i++) {
      final gx = i * 22 - (g.dist % 22);
      poly(c, [gx, gy + 20, gx + 11, gy + 44, gx + 22, gy + 20], const Color(0xFF4FAE26));
    }
    box(c, 0, gy, Game.width, 6, const Color(0xFF8BE04A));
  }

  void _front(Canvas c) {
    for (var i = 0; i < ferns.length; i++) {
      final fx = _wrap(ferns[i][0], g.dist * 1.3, 1680);
      final fh = ferns[i][1];
      _p
        ..style = PaintingStyle.fill
        ..color = i.isEven ? const Color(0xFF3D9E33) : const Color(0xFF2F8A2B);
      for (var k = -2; k <= 2; k++) {
        final path = Path()
          ..moveTo(fx, Game.height)
          ..quadraticBezierTo(fx + k * 22, Game.height - fh * .6, fx + k * 34,
              Game.height - fh + k.abs() * 14)
          ..quadraticBezierTo(fx + k * 14 + 10, Game.height - fh * .5, fx + 22, Game.height)
          ..close();
        c.drawPath(path, _p);
      }
    }
  }

  void _log(Canvas c, Obstacle o) {
    box(c, o.x, gy - o.h, o.w, o.h, const Color(0xFF8B5A2B));
    box(c, o.x, gy - o.h, o.w, 12, const Color(0xFFA56D38));
    box(c, o.x, gy - 12, o.w, 12, const Color(0xFF6E4520));
    ov(c, o.x + 4, gy - o.h / 2, 13, o.h / 2, const Color(0xFFC78F52));
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF8B5A2B);
    c.drawOval(
        Rect.fromCenter(center: Offset(o.x + 4, gy - o.h / 2), width: 14, height: o.h / 2),
        _p);
    _p.style = PaintingStyle.fill;
  }

  void _rock(Canvas c, Obstacle o) {
    poly(c, [o.x, gy, o.x + o.w * .3, gy - o.h, o.x + o.w * .75, gy - o.h * .8, o.x + o.w, gy],
        const Color(0xFF8B8A96));
    poly(c, [o.x + o.w * .3, gy - o.h, o.x + o.w * .75, gy - o.h * .8, o.x + o.w * .5, gy - o.h * .5],
        const Color(0xFFB4B3C0));
  }

  void _coin(Canvas c, Coin k) {
    final w = (cos(g.t * 4 + k.x * .01)).abs() * .5 + .5;
    ov(c, k.x, k.y, 22 * w + 2, 24, const Color(0xFFE8A410));
    ov(c, k.x, k.y, 18 * w + 1, 20, const Color(0xFFFFC928));
    if (w > .5) {
      const paw = Color(0xFFD9930A);
      circ(c, k.x, k.y + 4, 7 * w, paw);
      for (var i = -1; i <= 1; i++) {
        circ(c, k.x + i * 8 * w, k.y - 8, 3 * w, paw);
      }
    }
  }

  void _fox(Canvas c) {
    const orange = Color(0xFFF0701A), cream = Color(0xFFFFF3E2);
    final run = g.phase == Phase.play && !g.air ? sin(g.t * 16) : 0.2;
    final sw = g.air ? 0.9 : run;
    void leg(double a, double b, Color col) =>
        line(c, a, -36, a + b * 30, -8 - b.abs() * 6, col, 11);

    c.save();
    c.translate(200, gy + g.foxY);
    c.rotate(g.air ? (g.foxVy / 2500).clamp(-.35, .35).toDouble() : 0.0);
    leg(-22, sw, const Color(0xFF5A3418));
    leg(26, -sw, const Color(0xFF5A3418));
    // tail
    c.save();
    c.translate(-38, -50);
    c.rotate(sin(g.t * 10) * .12 - .25);
    ov(c, -34, 0, 44, 20, orange);
    ov(c, -66, 2, 18, 15, Colors.white);
    c.restore();
    // body
    ov(c, 0, -48, 46, 25, orange, -.1);
    ov(c, 14, -34, 26, 10, cream, .1);
    leg(-8, -sw, const Color(0xFF7A4420));
    leg(34, sw, const Color(0xFF7A4420));
    // ears
    poly(c, [26, -80, 34, -116, 52, -90], orange);
    poly(c, [52, -90, 76, -112, 76, -80], orange);
    poly(c, [35, -88, 37, -108, 47, -92], const Color(0xFFFFC0B0));
    // head
    circ(c, 54, -68, 26, orange);
    ov(c, 66, -56, 26, 14, cream, .2);
    circ(c, 88, -62, 5, const Color(0xFF2A1A10));
    circ(c, 66, -72, 7, const Color(0xFF1A1010));
    circ(c, 68, -74, 2.5, Colors.white);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF8A3410);
    c.drawArc(Rect.fromCircle(center: const Offset(72, -54), radius: 7), .2, 2.2, false, _p);
    _p.style = PaintingStyle.fill;
    c.restore();
  }

  @override
  bool shouldRepaint(covariant ScenePainter old) => true;
}

// ---------- Part 3: screen and buttons ----------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    title: 'Fox Forest Runner',
    debugShowCheckedModeBanner: false,
    home: HomePage(),
  ));
}

const _plankDark = Color(0xFF6B3A17);
const _cream = Color(0xFFFFF6DC);
const _orange = Color(0xFFF57C14);

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  final Game game = Game();
  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _ticker = createTicker((d) {
      var dt = (d - _last).inMicroseconds / 1e6;
      if (dt > .033) dt = .033;
      _last = d;
      if (!game.paused) game.update(dt);
      tick.value++;
    })..start();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ticker.dispose();
    tick.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyW) {
      game.jump();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyP || k == LogicalKeyboardKey.escape) {
      game.togglePause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  TextStyle _ts(double size, {bool shadow = true, Color color = _cream}) => TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1,
        decoration: TextDecoration.none,
        shadows: shadow ? [Shadow(color: _plankDark, offset: Offset(0, size * .07))] : null,
      );

  Widget _plank(double u, double w, double h, Widget child) => Container(
        width: w * u,
        height: h * u,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFA0612C), Color(0xFF8A5022)]),
          border: Border.all(color: _plankDark, width: .35 * u),
          borderRadius: BorderRadius.circular(u),
          boxShadow: [BoxShadow(color: const Color(0x80000000), offset: Offset(0, .5 * u))],
        ),
        child: child,
      );

  Widget _stat(double u, IconData icon, Color iconColor, String label, int value) =>
      Row(children: [
        SizedBox(width: 1.2 * u),
        Icon(icon, color: iconColor, size: 4.6 * u),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: _ts(2.4 * u)),
            SizedBox(height: .5 * u),
            Text('$value', style: _ts(4.2 * u)),
          ]),
        ),
      ]);

  Widget _round(double u, double size, IconData icon, VoidCallback onDown) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onDown(),
        child: Container(
          width: size * u,
          height: size * u,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _orange,
            border: Border.all(color: const Color(0xFFFFB25A), width: .4 * u),
          ),
          child: Icon(icon, color: Colors.white, size: size * .55 * u),
        ),
      );

  Widget _hud(double u) {
    final ph = game.phase;
    return Stack(children: [
      Positioned(
          left: 2.3 * u,
          top: 2 * u,
          child: IgnorePointer(
              child: _plank(u, 21.5, 6.8, _stat(u, Icons.emoji_events, const Color(0xFFFFC928), 'SCORE', game.score)))),
      Positioned(
          right: 11 * u,
          top: 2 * u,
          child: IgnorePointer(
              child: _plank(u, 17, 6.8, _stat(u, Icons.pets, const Color(0xFFFFC928), 'COINS', game.coins)))),
      Positioned(
          right: 2.3 * u,
          top: 2 * u,
          child: _round(u, 6.4, game.paused ? Icons.play_arrow : Icons.pause, game.togglePause)),
      Positioned(
          left: 2.3 * u,
          top: 10.5 * u,
          child: _round(u, 5.5, Icons.home, () => Navigator.of(context).maybePop())),
      if (ph == Phase.ready)
        Positioned(
            left: 0,
            right: 0,
            top: 14 * u,
            child: IgnorePointer(
                child: Center(
                    child: Transform.rotate(
                        angle: -.026,
                        child: _plank(u, 45, 9.5,
                            Center(child: Text('TAP TO START', style: _ts(6.2 * u)))))))),
      Positioned(
          left: 5.2 * u,
          bottom: 3.3 * u,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => game.jump(),
            child: Container(
              width: 15 * u,
              height: 11.3 * u,
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(3 * u),
                border: Border.all(color: const Color(0x88FFFFFF), width: .35 * u),
              ),
              child: Icon(Icons.arrow_upward, color: _cream, size: 7 * u),
            ),
          )),
      if (ph == Phase.over)
        Positioned(
            right: 2.5 * u,
            bottom: 2.7 * u,
            child: IgnorePointer(
              child: Container(
                width: 42 * u,
                height: 12 * u,
                padding: EdgeInsets.symmetric(horizontal: 2 * u),
                decoration: BoxDecoration(
                  color: const Color(0xD13C200C),
                  borderRadius: BorderRadius.circular(2.5 * u),
                  border: Border.all(color: const Color(0x4DFFFFFF), width: .3 * u),
                ),
                child: Row(children: [
                  Container(
                    width: 8.5 * u,
                    height: 8.5 * u,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _orange,
                        border: Border.all(color: const Color(0xFFFFB25A), width: .4 * u)),
                    child: Icon(Icons.refresh, color: Colors.white, size: 5.5 * u),
                  ),
                  SizedBox(width: 2.5 * u),
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('GAME OVER', style: _ts(4.6 * u, shadow: false, color: Colors.white)),
                    SizedBox(height: 1 * u),
                    Text('TAP TO PLAY AGAIN', style: _ts(2.3 * u, shadow: false, color: Colors.white)),
                    SizedBox(height: .6 * u),
                    Text('BEST ${game.best}', style: _ts(2 * u, shadow: false, color: const Color(0xFFFFC928))),
                  ]),
                ]),
              ),
            )),
      if (game.paused)
        Positioned.fill(
            child: IgnorePointer(
                child: Container(
                    color: const Color(0x59000000),
                    alignment: Alignment.center,
                    child: Text('PAUSED', style: _ts(8 * u, shadow: false, color: Colors.white))))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14221A),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Center(
          child: AspectRatio(
            aspectRatio: 1.5,
            child: ClipRect(
              child: LayoutBuilder(builder: (context, box) {
                final u = box.maxWidth / 100;
                return Stack(children: [
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => game.jump(),
                      child: CustomPaint(painter: ScenePainter(game, tick)),
                    ),
                  ),
                  Positioned.fill(
                    child: ValueListenableBuilder<int>(
                      valueListenable: tick,
                      builder: (context, _, __) => _hud(u),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Part 4: pages (Home, Privacy, Terms, Contact) ----------
// Edit these five lines with your real details.
const kAppName = 'Fox Forest Runner';
const kDeveloper = 'Your Name or Studio';
const kEmail = 'support@example.com';
const kCountry = 'your country';
const kUpdated = 'November 14, 2026';

const _brown = Color(0xFF5A3418);

BoxDecoration _woodDeco([double r = 16]) => BoxDecoration(
      gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA0612C), Color(0xFF8A5022)]),
      border: Border.all(color: _plankDark, width: 3),
      borderRadius: BorderRadius.circular(r),
      boxShadow: const [BoxShadow(color: Color(0x80000000), offset: Offset(0, 4))],
    );

TextStyle _wood(double s, [Color c = _cream]) => TextStyle(
      color: c,
      fontSize: s,
      fontWeight: FontWeight.w900,
      height: 1.1,
      decoration: TextDecoration.none,
      shadows: [Shadow(color: _plankDark, offset: Offset(0, s * .07))],
    );

void _go(BuildContext c, Widget p) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => p));

/// The animated fox: runs on the spot and jumps every second or so.
class Mascot extends StatefulWidget {
  final double size;
  const Mascot({super.key, this.size = 150});
  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  final Game g = Game()..phase = Phase.play;
  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  late final Ticker _tk;
  Duration _last = Duration.zero;
  double _wait = .5;

  @override
  void initState() {
    super.initState();
    _tk = createTicker((d) {
      var dt = (d - _last).inMicroseconds / 1e6;
      if (dt > .05) dt = .05;
      _last = d;
      g.t += dt;
      if (g.air) {
        g.foxVy += Game.gravity * dt;
        g.foxY += g.foxVy * dt;
        if (g.foxY >= 0) {
          g.foxY = 0;
          g.foxVy = 0;
          g.air = false;
          _wait = .9;
        }
      } else {
        _wait -= dt;
        if (_wait <= 0) {
          g.foxVy = -560;
          g.air = true;
        }
      }
      tick.value++;
    })
      ..start();
  }

  @override
  void dispose() {
    _tk.dispose();
    tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _MascotPainter(ScenePainter(g, tick), tick)),
      );
}

class _MascotPainter extends CustomPainter {
  final ScenePainter sp;
  _MascotPainter(this.sp, Listenable r) : super(repaint: r);
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 240, s.height / 240);
    c.translate(-75, -250);
    sp.ov(c, 200, 440, 60, 8, const Color(0x33000000));
    sp._fox(c);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

/// Slowly scrolling forest behind every page.
class ForestBackdrop extends StatefulWidget {
  final Widget child;
  const ForestBackdrop({super.key, required this.child});
  @override
  State<ForestBackdrop> createState() => _ForestBackdropState();
}

class _ForestBackdropState extends State<ForestBackdrop>
    with SingleTickerProviderStateMixin {
  final Game g = Game();
  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  late final Ticker _tk;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tk = createTicker((d) {
      var dt = (d - _last).inMicroseconds / 1e6;
      if (dt > .05) dt = .05;
      _last = d;
      g.t += dt;
      g.dist += 110 * dt;
      tick.value++;
    })
      ..start();
  }

  @override
  void dispose() {
    _tk.dispose();
    tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _BackdropPainter(ScenePainter(g, tick), tick)),
        widget.child,
      ]);
}

class _BackdropPainter extends CustomPainter {
  final ScenePainter sp;
  _BackdropPainter(this.sp, Listenable r) : super(repaint: r);
  @override
  void paint(Canvas c, Size s) {
    final k = max(s.width / Game.width, s.height / Game.height);
    c.save();
    c.translate((s.width - Game.width * k) / 2, s.height - Game.height * k);
    c.scale(k, k);
    sp._background(c);
    sp._ground(c);
    sp._front(c);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

Widget _menuBtn(String label, IconData icon, Color color, VoidCallback onTap,
        {double w = 290, double h = 56}) =>
    SizedBox(
      width: w,
      height: h,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white54, width: 2)),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 26),
        label: Text(label),
      ),
    );

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14221A),
      body: ForestBackdrop(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 760;
            final logo = Image.asset('assets/images/logo.png',
                width: wide ? 380 : 280,
                errorBuilder: (_, __, ___) => Text(kAppName, style: _wood(36)));
            final menu = Column(mainAxisSize: MainAxisSize.min, children: [
              _menuBtn('PLAY', Icons.play_arrow, _orange,
                  () => _go(context, const GamePage()), h: 64),
              const SizedBox(height: 12),
              _menuBtn('Privacy Policy', Icons.privacy_tip, const Color(0xFF3F9A34),
                  () => _go(context, const PrivacyPage())),
              const SizedBox(height: 10),
              _menuBtn('Terms & Conditions', Icons.gavel, const Color(0xFF2F7FB8),
                  () => _go(context, const TermsPage())),
              const SizedBox(height: 10),
              _menuBtn('Contact Us', Icons.mail, const Color(0xFF8A4FB8),
                  () => _go(context, const ContactPage())),
            ]);
            final foot = Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text('Version 1.0.0   ©  2026 $kDeveloper', style: _wood(13)),
            );
            final content = wide
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Mascot(size: 300),
                    const SizedBox(width: 30),
                    Column(mainAxisSize: MainAxisSize.min, children: [logo, const SizedBox(height: 10), menu, foot]),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    logo,
                    const Mascot(size: 190),
                    menu,
                    foot,
                  ]);
            return Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16), child: content),
            );
          }),
        ),
      ),
    );
  }
}

/// Shared look for the text pages: wooden title, jumping fox, paper card.
class ForestPage extends StatelessWidget {
  final String title;
  final Widget body;
  const ForestPage({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14221A),
      body: ForestBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(children: [
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: _orange),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: _woodDeco(),
                        child: Text(title, textAlign: TextAlign.center, style: _wood(26)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Mascot(size: 100),
                  ]),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xF5FFF6DC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _plankDark, width: 3),
                    ),
                    child: SingleChildScrollView(child: body),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Doc extends StatelessWidget {
  final List<List<String>> items;
  const _Doc(this.items);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in items) ...[
            Text(s[0],
                style: const TextStyle(
                    color: _brown, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(s[1],
                style: const TextStyle(color: Color(0xFF3B2410), fontSize: 15, height: 1.5)),
            const SizedBox(height: 18),
          ],
        ],
      );
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => const ForestPage(
        title: 'Privacy Policy',
        body: _Doc([
          ['Last updated', kUpdated],
          ['Overview', '$kAppName is a simple endless-runner game. It is designed to work without collecting any personal information about you.'],
          ['Information we collect', 'We do not collect, store on a server, sell or share personal information. The game has no accounts, no ads, no analytics and no tracking. Your best score stays on your own device, or only while the app is open.'],
          ['Permissions', 'The game does not ask for access to your camera, microphone, contacts, location, photos or files.'],
          ['Third parties', 'The game does not include third-party advertising or analytics tools. The store or website you download or play it from (for example Google Play, the App Store or a web host) may collect its own technical data under its own policy.'],
          ['Children', 'The game is suitable for all ages. We do not knowingly collect personal information from anyone, including children.'],
          ['Changes to this policy', 'If the game changes in a way that affects your privacy, we will update this page and the date above.'],
          ['Contact', 'Questions about privacy? Email $kEmail.'],
        ]),
      );
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});
  @override
  Widget build(BuildContext context) => const ForestPage(
        title: 'Terms & Conditions',
        body: _Doc([
          ['Last updated', kUpdated],
          ['Accepting these terms', 'By downloading, opening or playing $kAppName you agree to these terms. If you do not agree, please do not use the game.'],
          ['Using the game', 'You may play the game for personal, non-commercial use. Please do not copy, sell, reverse engineer or re-upload the game, or use cheats or tools that harm it or other people.'],
          ['Ownership', 'The game, its fox character, artwork, logo and code belong to $kDeveloper. You get a limited right to play it, not ownership of it.'],
          ['No warranty', 'The game is provided "as is". We try to keep it working well, but we cannot promise it will always be free of errors or available without interruption.'],
          ['Limit of liability', 'To the extent allowed by law, $kDeveloper is not responsible for any loss or damage that comes from using or not being able to use the game.'],
          ['Changes', 'We may update the game or these terms from time to time. Continuing to play after an update means you accept the new terms.'],
          ['Governing law', 'These terms follow the laws of $kCountry.'],
          ['Contact', 'Questions about these terms? Email $kEmail.'],
        ]),
      );
}

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  Widget _card(IconData i, String t, String d, [Widget? extra]) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE9B8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD9A441), width: 2),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: _orange, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: const TextStyle(color: _brown, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(d, style: const TextStyle(color: Color(0xFF3B2410), fontSize: 15, height: 1.4)),
              if (extra != null) ...[const SizedBox(height: 10), extra],
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => ForestPage(
        title: 'Contact Us',
        body: Builder(
          builder: (ctx) => Column(children: [
            _card(
              Icons.email,
              'Email us',
              kEmail,
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: kEmail));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Email address copied')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy email'),
              ),
            ),
            _card(Icons.bug_report, 'Report a bug',
                'Tell us which device you use, what you were doing and what went wrong.'),
            _card(Icons.lightbulb, 'Share an idea',
                'New obstacles, new levels or a new fox outfit? We would love to hear it.'),
            _card(Icons.schedule, 'Reply time',
                'We usually reply within 2 to 3 business days.'),
          ]),
        ),
      );
}
