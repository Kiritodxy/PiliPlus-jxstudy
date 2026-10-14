import 'dart:math' as math;

import 'package:PiliPlus/models/common/particle_style.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 把 [child] 叠在动态粒子背景之上；设置关闭时不渲染背景（同时销毁动画，零开销）。
///
/// 用法：页面 build 最外层直接 `return ParticleBackgroundLayer(child: ...);`
class ParticleBackgroundLayer extends StatelessWidget {
  const ParticleBackgroundLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Obx(() {
            if (!GlobalData().enableParticleBg.value) {
              return const SizedBox.shrink();
            }
            return ParticleBackground(style: GlobalData().particleStyle.value);
          }),
        ),
        child,
      ],
    );
  }
}

/// 全局共享的「粒子世界」。
///
/// 所有页面（首页/我的、搜索页、设置页及其子页）复用**同一批粒子**与**同一个 Ticker**，
/// 因此页面切换时画面连续：粒子不会重新生成，动画相位也不会重置。
/// 仅当没有任何页面在显示时才会停止 Ticker（省电，与原先关闭背景时零开销一致）。
class _ParticleWorld {
  _ParticleWorld._();

  static final _ParticleWorld instance = _ParticleWorld._();

  static const int _particleCount = 56;
  static const int _sakuraActive = 20;
  static const int _ripplesActive = 8;

  final _rnd = math.Random(20260704);
  final List<_Particle> particles = [];
  Size size = Size.zero;
  Duration last = Duration.zero;
  ParticleStyle style = ParticleStyle.floating;

  final Set<VoidCallback> _listeners = <VoidCallback>{};
  Ticker? _ticker;

  /// 页面挂载：多个页面同时存在时也只有第一个负责驱动 Ticker
  void attach(VoidCallback repaint, ParticleStyle value) {
    _listeners.add(repaint);
    if (_listeners.length != 1) return;
    if (style != value) setStyle(value);
    _ticker ??= Ticker(_onTick);
    if (!_ticker!.isActive) {
      last = Duration.zero; // 重新进入时首帧不推进，避免跳跃
      _ticker!.start();
    }
  }

  void detach(VoidCallback repaint) {
    _listeners.remove(repaint);
    if (_listeners.isNotEmpty) return;
    _ticker?.stop();
    last = Duration.zero;
  }

  /// 用户在设置里切换样式时重建粒子
  void setStyle(ParticleStyle value) {
    if (style == value) return;
    style = value;
    particles
      ..clear()
      ..addAll(_build());
    _notify();
  }

  /// 同步当前页面的可见尺寸：粒子坐标**保持不变**（跨页面绝对连续），
  /// 越界的粒子由 update 里的回绕逻辑自然带回画面内。
  void resize(Size value) {
    size = value;
    if (particles.isEmpty) particles.addAll(_build());
  }

  List<_Particle> _build() {
    if (size.isEmpty) return const [];
    return List<_Particle>.generate(_particleCount, (i) => _create(i, size));
  }

  void _onTick(Duration elapsed) {
    final dt = last == Duration.zero
        ? 0.0
        : math.min(
            (elapsed - last).inMicroseconds / 1000000.0,
            0.04,
          ); // 上限 40ms，避免后台回前台跳帧
    last = elapsed;
    if (size.isEmpty || particles.isEmpty) return;
    for (final p in particles) {
      p.update(dt, size, style, _rnd);
    }
    _notify();
  }

  void _notify() {
    for (final f in _listeners.toList(growable: false)) {
      f();
    }
  }

  _Particle _create(int index, Size size) {
    final p = _Particle();
    final style = this.style;
    p.x = _rnd.nextDouble() * size.width;
    p.y = _rnd.nextDouble() * size.height;
    switch (style) {
      case ParticleStyle.rain:
        p.radius = 1.6 + _rnd.nextDouble() * 1.2;
        p.length = 9 + _rnd.nextDouble() * 13;
        p.speedX = 42 + _rnd.nextDouble() * 32;
        p.speedY = 128 + _rnd.nextDouble() * 96;
      case ParticleStyle.star:
        p.radius = 1.4 + _rnd.nextDouble() * 2.5;
        p.minAlpha = 18 + _rnd.nextInt(28);
        p.maxAlpha = 178 + _rnd.nextInt(68);
        p.pulsePhase = _rnd.nextDouble() * math.pi * 2;
        p.pulseSpeed = 1.15 + _rnd.nextDouble() * 1.35;
      case ParticleStyle.sakura:
        p.rotation = _rnd.nextDouble() * math.pi * 2;
        p.rotationSpeed = (_rnd.nextDouble() - 0.5) * 2.0;
        p.shapeType = _rnd.nextInt(4);
        if (index >= _sakuraActive) {
          p.radius = 0;
          p.alpha = 0;
        } else {
          p.radius = 7;
          p.speedX = (_rnd.nextDouble() - 0.5) * 40;
          p.speedY = 30 + _rnd.nextDouble() * 30;
          p.alpha = 120 + _rnd.nextInt(60);
        }
      case ParticleStyle.fireflies:
        p.radius = 2 + _rnd.nextDouble() * 2;
        p.wanderAngle = _rnd.nextDouble() * math.pi * 2;
        p.wanderSpeed = 8 + _rnd.nextDouble() * 10;
        p.minAlpha = 20 + _rnd.nextInt(30);
        p.maxAlpha = 180 + _rnd.nextInt(60);
        p.pulsePhase = _rnd.nextDouble() * math.pi * 2;
        p.pulseSpeed = 0.8 + _rnd.nextDouble() * 1.2;
      case ParticleStyle.constellation:
        p.radius = 1.5 + _rnd.nextDouble() * 1.5;
        p.speedX = (_rnd.nextDouble() - 0.5) * 16;
        p.speedY = (_rnd.nextDouble() - 0.5) * 16;
        p.alpha = 100 + _rnd.nextInt(60);
      case ParticleStyle.ripples:
        if (index >= _ripplesActive) {
          p.maxRadius = 0;
        } else {
          p.rippleProgress = _rnd.nextDouble();
          p.rippleSpeed = 0.1 + _rnd.nextDouble() * 0.15;
          p.maxRadius = 60 + _rnd.nextDouble() * 40;
        }
      case ParticleStyle.floating:
        p.radius = 2.2 + _rnd.nextDouble() * 4.2;
        p.speedX = (_rnd.nextDouble() - 0.5) * 10;
        p.speedY = -(7 + _rnd.nextDouble() * 18);
    }
    p.colorIndex = _rnd.nextInt(_palette.length);
    if (style == ParticleStyle.floating ||
        style == ParticleStyle.rain ||
        style == ParticleStyle.star) {
      p.alpha = 58 + _rnd.nextInt(54);
    }
    return p;
  }

  static const List<Color> _palette = [
    Color(0xFF22D88E),
    Color(0xFF4A90E2),
    Color(0xFFFFB84C),
    Color(0xFFFF6484),
    Color(0xFF9672FF),
  ];
}

/// 动态粒子背景（移植自开源项目 Rinne Mobile 的 LauncherParticleView）。
///
/// 7 种样式：floating / rain / star / sakura / fireflies / constellation / ripples。
/// 纯 Canvas 绘制，无素材、无额外依赖。
///
/// 实例本身不持有粒子数据——数据在全局 `_ParticleWorld` 里，多个页面共享同一套画面。
class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key, required this.style});

  final ParticleStyle style;

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> {
  final _ParticleWorld _world = _ParticleWorld.instance;

  @override
  void initState() {
    super.initState();
    _world.attach(_repaint, widget.style);
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ParticleBackground old) {
    super.didUpdateWidget(old);
    if (widget.style != old.style) _world.setStyle(widget.style);
  }

  @override
  void dispose() {
    _world.detach(_repaint);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _world.resize(size);
        return IgnorePointer(
          child: CustomPaint(
            size: size,
            painter: _ParticlePainter(
              particles: _world.particles,
              style: _world.style,
              palette: _ParticleWorld._palette,
              timeSeconds: _world.last.inMicroseconds / 1000000.0,
            ),
          ),
        );
      },
    );
  }
}
class _Particle {
  double x = 0, y = 0, radius = 0;
  double speedX = 0, speedY = 0, length = 0;
  int colorIndex = 0;
  int alpha = 0, minAlpha = 0, maxAlpha = 0;
  double pulsePhase = 0, pulseSpeed = 0;
  double rotation = 0, rotationSpeed = 0;
  int shapeType = 0;
  double wanderAngle = 0, wanderSpeed = 0;
  double rippleProgress = 0, rippleSpeed = 0, maxRadius = 0;

  void update(double dt, Size size, ParticleStyle style, math.Random rnd) {
    if (dt <= 0) return;
    final w = size.width, h = size.height;
    switch (style) {
      case ParticleStyle.star:
        return; // 只闪烁，不移动
      case ParticleStyle.sakura:
        if (radius <= 0) return;
        y += speedY * dt;
        x += speedX * dt;
        rotation += rotationSpeed * dt;
        final margin = radius;
        if (y > h + margin) {
          y = -margin;
          x = rnd.nextDouble() * w;
        }
        if (x < margin) {
          x = margin;
          speedX = -speedX;
        } else if (x > w - margin) {
          x = w - margin;
          speedX = -speedX;
        }
      case ParticleStyle.fireflies:
        wanderAngle += (rnd.nextDouble() - 0.5) * 3.0 * dt;
        x += math.cos(wanderAngle) * wanderSpeed * dt;
        y += math.sin(wanderAngle) * wanderSpeed * dt;
        const margin = 14.0;
        if (x < -margin) {
          x = w + margin;
        } else if (x > w + margin) {
          x = -margin;
        }
        if (y < -margin) {
          y = h + margin;
        } else if (y > h + margin) {
          y = -margin;
        }
      case ParticleStyle.constellation:
        x += speedX * dt;
        y += speedY * dt;
        if (x < 0 || x > w) speedX = -speedX;
        if (y < 0 || y > h) speedY = -speedY;
      case ParticleStyle.ripples:
        if (maxRadius <= 0) return;
        rippleProgress += rippleSpeed * dt;
        if (rippleProgress >= 1) {
          rippleProgress = 0;
          x = rnd.nextDouble() * w;
          y = rnd.nextDouble() * h;
          colorIndex = rnd.nextInt(_ParticleWorld._palette.length);
        }
      case ParticleStyle.rain:
      case ParticleStyle.floating:
        x += speedX * dt;
        y += speedY * dt;
        final margin = radius * 2;
        if (speedY < 0 && y < -margin) {
          y = h + margin;
        } else if (speedY > 0 && y > h + margin) {
          y = -margin;
        }
        if (x < -margin) {
          x = w + margin;
        } else if (x > w + margin) {
          x = -margin;
        }
    }
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.style,
    required this.palette,
    required this.timeSeconds,
  });

  final List<_Particle> particles;
  final ParticleStyle style;
  final List<Color> palette;
  final double timeSeconds;

  Color _color(int index) => palette[index % palette.length];

  int _pulseAlpha(_Particle p) {
    final progress =
        (math.sin(timeSeconds * p.pulseSpeed + p.pulsePhase) + 1) * 0.5;
    final eased = progress * progress;
    return (p.minAlpha + (p.maxAlpha - p.minAlpha) * eased).round();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    if (style == ParticleStyle.constellation) {
      _paintConstellation(canvas, paint, size);
      return;
    }
    for (final p in particles) {
      final color = _color(p.colorIndex);
      switch (style) {
        case ParticleStyle.rain:
          paint
            ..shader = null
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.radius
            ..strokeCap = StrokeCap.round;
          _withAlpha(paint, color, p.alpha);
          canvas.drawLine(
            Offset(p.x - p.length * 0.34, p.y - p.length),
            Offset(p.x, p.y),
            paint,
          );
        case ParticleStyle.star:
          paint
            ..shader = null
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..strokeCap = StrokeCap.round;
          _withAlpha(paint, color, _pulseAlpha(p));
          canvas.drawLine(
            Offset(p.x - p.radius, p.y),
            Offset(p.x + p.radius, p.y),
            paint,
          );
          canvas.drawLine(
            Offset(p.x, p.y - p.radius),
            Offset(p.x, p.y + p.radius),
            paint,
          );
        case ParticleStyle.sakura:
          if (p.radius <= 0) continue;
          paint
            ..shader = null
            ..style = PaintingStyle.fill;
          _withAlpha(paint, color, p.alpha);
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.rotation);
          final r = p.radius;
          switch (p.shapeType) {
            case 0: // 方块
              canvas.drawRect(Rect.fromLTRB(-r, -r, r, r), paint);
            case 1: // 三角
              final path = Path()
                ..moveTo(0, -r)
                ..lineTo(r * 0.866, r * 0.5)
                ..lineTo(-r * 0.866, r * 0.5)
                ..close();
              canvas.drawPath(path, paint);
            case 2: // 圆
              canvas.drawCircle(Offset.zero, r, paint);
            case 3: // 十字
              canvas.drawRect(
                Rect.fromLTRB(-r, -r * 0.3, r, r * 0.3),
                paint,
              );
              canvas.drawRect(
                Rect.fromLTRB(-r * 0.3, -r, r * 0.3, r),
                paint,
              );
          }
          canvas.restore();
        case ParticleStyle.fireflies:
          final alpha = _pulseAlpha(p);
          canvas.save();
          canvas.translate(p.x, p.y);
          paint
            ..shader = RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: 14))
            ..style = PaintingStyle.fill;
          _withAlpha(paint, color, alpha);
          canvas.drawCircle(Offset.zero, 14, paint);
          paint
            ..shader = null
            ..color = color;
          canvas.drawCircle(Offset.zero, p.radius, paint);
          canvas.restore();
        case ParticleStyle.ripples:
          if (p.maxRadius <= 0) continue;
          paint
            ..shader = null
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;
          final r = p.rippleProgress * p.maxRadius;
          _withAlpha(paint, color, ((1 - p.rippleProgress) * 180).round());
          canvas.drawCircle(Offset(p.x, p.y), r, paint);
          final inner = p.rippleProgress - 0.3;
          if (inner > 0) {
            _withAlpha(paint, color, ((1 - inner) * 90).round());
            canvas.drawCircle(Offset(p.x, p.y), inner * p.maxRadius, paint);
          }
        case ParticleStyle.constellation:
          break;
        case ParticleStyle.floating:
          paint
            ..shader = null
            ..style = PaintingStyle.fill;
          _withAlpha(paint, color, p.alpha);
          canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
      }
    }
  }

  void _paintConstellation(Canvas canvas, Paint paint, Size size) {
    const maxDist = 80.0;
    paint.style = PaintingStyle.fill;
    for (final p in particles) {
      _withAlpha(paint, _color(p.colorIndex), p.alpha);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < particles.length; i++) {
      final a = particles[i];
      for (var j = i + 1; j < particles.length; j++) {
        final b = particles[j];
        final dx = a.x - b.x;
        final dy = a.y - b.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < maxDist) {
          _withAlpha(
            paint,
            _color(a.colorIndex),
            ((1 - dist / maxDist) * 80).round(),
          );
          canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);
        }
      }
    }
  }

  void _withAlpha(Paint paint, Color color, int alpha) {
    paint.color = color.withValues(alpha: alpha.clamp(0, 255) / 255);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
