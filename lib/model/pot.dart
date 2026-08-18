import 'dart:math' as math;
import 'dart:typed_data';

const int kRows = 32;
const int kCols = 52;

const double kMinRadius = 0.035;
const double kMaxRadius = 0.44;

const int kNoGlaze = 0;
const int kClayArgb = 0xFFE2685C;

class Pot {
  Pot({
    required this.profile,
    required this.glaze,
    required this.id,
    required this.createdAt,
  });

  factory Pot.fresh() => Pot(
        profile: List<double>.generate(kRows + 1, (i) {
          final y = i / kRows;
          return 0.190 + 0.040 * math.sin(y * math.pi) - 0.020 * y;
        }),
        glaze: Int32List((kRows + 1) * kCols),
        id: _newId(),
        createdAt: DateTime.now(),
      );

  final List<double> profile;
  final Int32List glaze;
  final String id;
  final DateTime createdAt;

  int revision = 0;

  static String _newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  double radiusAt(double y) {
    final t = y.clamp(0.0, 1.0) * kRows;
    final i = t.floor().clamp(0, kRows);
    final j = math.min(i + 1, kRows);
    return profile[i] + (profile[j] - profile[i]) * (t - i);
  }

  void push({required double y, required double delta, double sigma = 0.085}) {
    for (var i = 0; i <= kRows; i++) {
      final d = (i / kRows - y) / sigma;
      if (d.abs() > 3.0) continue;
      final w = math.exp(-0.5 * d * d);
      profile[i] = (profile[i] + delta * w).clamp(kMinRadius, kMaxRadius);
    }
    relax(0.18);
    revision++;
  }

  void relax([double amount = 0.2]) {
    final src = List<double>.of(profile);
    for (var i = 1; i < kRows; i++) {
      final avg = (src[i - 1] + src[i + 1]) * 0.5;
      profile[i] = src[i] + (avg - src[i]) * amount;
    }
  }

  void glazeSplat({
    required double y,
    required int col,
    required int argb,
    double rowSigma = 1.3,
    double colSigma = 2.0,
    double strength = 0.9,
  }) {
    final centerRow = y.clamp(0.0, 1.0) * kRows;
    final rowSpan = (rowSigma * 2.5).ceil();
    final colSpan = (colSigma * 2.5).ceil();
    for (var i = centerRow.round() - rowSpan;
        i <= centerRow.round() + rowSpan;
        i++) {
      if (i < 0 || i > kRows) continue;
      final dr = (i - centerRow) / rowSigma;
      for (var dc = -colSpan; dc <= colSpan; dc++) {
        final dcn = dc / colSigma;
        final w = math.exp(-0.5 * (dr * dr + dcn * dcn)) * strength;
        if (w < 0.02) continue;
        var j = (col + dc) % kCols;
        if (j < 0) j += kCols;
        final idx = i * kCols + j;
        glaze[idx] = _blend(glaze[idx], argb, w);
      }
    }
    revision++;
  }

  static int _blend(int from, int to, double t) {
    final f = from == kNoGlaze ? kClayArgb : from;
    final k = 1 - t;
    final r = (((f >> 16) & 0xFF) * k + ((to >> 16) & 0xFF) * t).round();
    final g = (((f >> 8) & 0xFF) * k + ((to >> 8) & 0xFF) * t).round();
    final b = ((f & 0xFF) * k + (to & 0xFF) * t).round();
    return 0xFF000000 | (r << 16) | (g << 8) | b;
  }

  void stripGlaze() {
    glaze.fillRange(0, glaze.length, kNoGlaze);
    revision++;
  }

  PotSnapshot snapshot() =>
      PotSnapshot(List<double>.of(profile), Int32List.fromList(glaze));

  void restore(PotSnapshot s) {
    profile.setAll(0, s.profile);
    glaze.setAll(0, s.glaze);
    revision++;
  }

  Pot duplicate({String? id}) => Pot(
        profile: List<double>.of(profile),
        glaze: Int32List.fromList(glaze),
        id: id ?? _newId(),
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'rows': kRows,
        'cols': kCols,
        'profile': profile,
        'glaze': glaze.toList(),
      };

  static Pot? tryFromJson(Map<String, dynamic> json) {
    if (json['rows'] != kRows || json['cols'] != kCols) return null;
    final profile = (json['profile'] as List<dynamic>?)
        ?.map((e) => (e as num).toDouble())
        .toList();
    final glaze = (json['glaze'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList();
    if (profile == null || profile.length != kRows + 1) return null;
    if (glaze == null || glaze.length != (kRows + 1) * kCols) return null;
    return Pot(
      profile: profile,
      glaze: Int32List.fromList(glaze),
      id: json['id'] as String? ?? _newId(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class PotSnapshot {
  PotSnapshot(this.profile, this.glaze);

  final List<double> profile;
  final Int32List glaze;
}
