import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../model/palette.dart';
import '../model/pot.dart';
import '../model/wheel.dart';

const double kTilt = 0.30;
const double kLean = 0.016;

const double _lx = -0.412, _ly = 0.618, _lz = 0.670;
const double _hx = -0.246, _hy = 0.369, _hz = 0.897;

class PotView {
  PotView(Size size)
      : scale = math.min(size.height * 0.60, size.width / 0.95),
        cx = size.width / 2,
        baseY = size.height * 0.76;

  final double scale;
  final double cx;
  final double baseY;

  Offset project(double r, double y, double sinT, double cosT) => Offset(
        cx + scale * r * sinT,
        baseY - scale * y + kTilt * scale * r * cosT,
      );

  double heightAt(Offset p, Pot pot) {
    var y = (baseY - p.dy) / scale;
    for (var i = 0; i < 2; i++) {
      final r = math.max(pot.radiusAt(y.clamp(0.0, 1.0)), 1e-4);
      final sinT = ((p.dx - cx) / scale / r).clamp(-1.0, 1.0);
      final cosT = math.sqrt(1 - sinT * sinT);
      y = (baseY - p.dy + kTilt * scale * r * cosT) / scale;
    }
    return y.clamp(0.0, 1.0);
  }

  bool hitsPot(Offset p, Pot pot) {
    final rim = baseY - scale - kTilt * scale * pot.profile[kRows] - 8;
    final foot = baseY + kTilt * scale * pot.profile[0] + 8;
    if (p.dy < rim || p.dy > foot) return false;
    final slop = 12 / scale;
    return (p.dx - cx).abs() / scale <= pot.radiusAt(heightAt(p, pot)) + slop;
  }

  int columnAt(Offset p, Pot pot, double y, double rotation) {
    final r = math.max(pot.radiusAt(y), 1e-4);
    final sinT = ((p.dx - cx) / scale / r).clamp(-1.0, 1.0);
    final theta = math.asin(sinT) - rotation;
    var col = (theta / (2 * math.pi) * kCols).round() % kCols;
    if (col < 0) col += kCols;
    return col;
  }
}

class _Mesh {
  static final Float32List positions = Float32List((kRows + 1) * kCols * 2);
  static final Int32List colors = Int32List((kRows + 1) * kCols);
  static final Uint16List indices = Uint16List(kRows * kCols * 6);
  static final Float32List depth = Float32List(kRows * kCols);
  static final List<int> order = List<int>.filled(kRows * kCols, 0);
  static final Float32List sinT = Float32List(kCols);
  static final Float32List cosT = Float32List(kCols);
  static final Float32List grain = _buildGrain();
}

Float32List _buildGrain() {
  final g = Float32List((kRows + 1) * kCols);
  for (var i = 0; i <= kRows; i++) {
    for (var j = 0; j < kCols; j++) {
      final spiral =
          math.sin(2 * math.pi * (i * 6.0 / kRows + j * 2.0 / kCols)) * 0.045;
      g[i * kCols + j] = spiral + _tooth(i, j) * 0.055;
    }
  }
  return g;
}

double _tooth(int i, int j) {
  var h = (i * 73856093) ^ (j * 19349663);
  h = (h ^ (h >> 13)) * 1274126177;
  return ((h & 0xFFFF) / 0xFFFF) - 0.5;
}

double _smoothstep(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

int _shadeArgb(int base, double shade, double spec) {
  final r = (((base >> 16) & 0xFF) * shade + 255 * spec).clamp(0.0, 255.0);
  final g = (((base >> 8) & 0xFF) * shade + 255 * spec).clamp(0.0, 255.0);
  final b = ((base & 0xFF) * shade + 255 * spec).clamp(0.0, 255.0);
  return 0xFF000000 | (r.toInt() << 16) | (g.toInt() << 8) | b.toInt();
}

void paintPot(
  Canvas canvas,
  Size size,
  Pot pot,
  double rotation, {
  bool wheel = true,
}) {
  final view = PotView(size);
  if (wheel) _paintWheelHead(canvas, view);
  _paintClay(canvas, view, pot, rotation);
}

void _paintWheelHead(Canvas canvas, PotView v) {
  final rw = 0.26 * v.scale;
  final ry = rw * kTilt;
  final thickness = v.scale * 0.028;

  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(v.cx, v.baseY + ry * 0.9),
      width: rw * 2.5,
      height: ry * 2.8,
    ),
    Paint()
      ..color = kWheelEdge.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
  );

  final top = Rect.fromCenter(
    center: Offset(v.cx, v.baseY),
    width: rw * 2,
    height: ry * 2,
  );
  final body = Path()
    ..addOval(top)
    ..addRect(Rect.fromLTRB(v.cx - rw, v.baseY, v.cx + rw, v.baseY + thickness))
    ..addOval(top.shift(Offset(0, thickness)));
  canvas.drawPath(body, Paint()..color = kWheelEdge);
  canvas.drawOval(
    top,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7C453D), kWheelDark],
      ).createShader(top),
  );
}

void _paintClay(Canvas canvas, PotView v, Pot pot, double rotation) {
  final step = 2 * math.pi / kCols;
  final leanX = math.sin(rotation);
  final leanZ = math.cos(rotation);

  for (var j = 0; j < kCols; j++) {
    final t = rotation + j * step;
    _Mesh.sinT[j] = math.sin(t);
    _Mesh.cosT[j] = math.cos(t);
  }

  for (var i = 0; i <= kRows; i++) {
    final y = i / kRows;
    final r = pot.profile[i];

    final prev = i == 0 ? 0 : i - 1;
    final next = i == kRows ? kRows : i + 1;
    final dy = (next - prev) / kRows;
    final slope = (pot.profile[next] - pot.profile[prev]) / dy;
    final len = math.sqrt(1 + slope * slope);
    final nr = 1 / len;
    final ny = -slope / len;

    final ao = 0.45 + 0.55 * _smoothstep(0.0, 0.10, y);
    final lean = kLean * y * y;

    for (var j = 0; j < kCols; j++) {
      final s = _Mesh.sinT[j];
      final c = _Mesh.cosT[j];
      final vi = i * kCols + j;

      _Mesh.positions[vi * 2] = v.cx + v.scale * (r * s + lean * leanX);
      _Mesh.positions[vi * 2 + 1] = v.baseY -
          v.scale * y +
          kTilt * v.scale * (r * c + lean * leanZ);

      final nx = nr * s;
      final nz = nr * c;
      var lambert = nx * _lx + ny * _ly + nz * _lz;
      if (lambert < 0) lambert = 0;
      var shade = 0.34 + 0.74 * lambert;
      var spec = 0.0;

      if (nz > 0) {
        final h = nx * _hx + ny * _hy + nz * _hz;
        if (h > 0) {
          final h4 = (h * h) * (h * h);
          final h8 = h4 * h4;
          spec = 0.30 * h8 * h8 * h4;
        }
      } else {
        shade = shade * (1 + nz * 0.28) + 0.14 * -nz;
      }

      final glazed = pot.glaze[vi] != kNoGlaze;
      shade *= ao * (1 + _Mesh.grain[vi] * (glazed ? 0.35 : 1.0));
      final base = glazed ? pot.glaze[vi] : kClayArgb;
      _Mesh.colors[vi] = _shadeArgb(base, shade, spec * ao);
    }
  }

  for (var i = 0; i < kRows; i++) {
    for (var j = 0; j < kCols; j++) {
      final q = i * kCols + j;
      final j2 = (j + 1) % kCols;
      final rMid = (pot.profile[i] + pot.profile[i + 1]) * 0.5;
      _Mesh.depth[q] = rMid * (_Mesh.cosT[j] + _Mesh.cosT[j2]) * 0.5;
      _Mesh.order[q] = q;
    }
  }
  _Mesh.order.sort((a, b) => _Mesh.depth[a].compareTo(_Mesh.depth[b]));

  var k = 0;
  for (final q in _Mesh.order) {
    final i = q ~/ kCols;
    final j = q % kCols;
    final j2 = (j + 1) % kCols;
    final v00 = i * kCols + j;
    final v01 = i * kCols + j2;
    final v10 = (i + 1) * kCols + j;
    final v11 = (i + 1) * kCols + j2;
    _Mesh.indices[k++] = v00;
    _Mesh.indices[k++] = v10;
    _Mesh.indices[k++] = v11;
    _Mesh.indices[k++] = v00;
    _Mesh.indices[k++] = v11;
    _Mesh.indices[k++] = v01;
  }

  final vertices = ui.Vertices.raw(
    ui.VertexMode.triangles,
    _Mesh.positions,
    colors: _Mesh.colors,
    indices: _Mesh.indices,
  );
  canvas.drawVertices(vertices, BlendMode.srcOver, Paint());
}

class PotPainter extends CustomPainter {
  PotPainter({
    required this.pot,
    this.spin,
    this.angle = 0.7,
    this.wheel = true,
  }) : super(repaint: spin);

  final Pot pot;
  final WheelSpin? spin;
  final double angle;
  final bool wheel;

  @override
  void paint(Canvas canvas, Size size) {
    paintPot(canvas, size, pot, spin?.angle ?? angle, wheel: wheel);
  }

  @override
  bool shouldRepaint(PotPainter old) =>
      !identical(old.pot, pot) ||
      old.pot.revision != pot.revision ||
      !identical(old.spin, spin) ||
      old.angle != angle ||
      old.wheel != wheel;
}
