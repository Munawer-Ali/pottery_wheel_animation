import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pottery_wheel/model/pot.dart';
import 'package:pottery_wheel/model/wheel.dart';
import 'package:pottery_wheel/render/pot_painter.dart';
import 'package:pottery_wheel/screens/studio_screen.dart';

Pot potOnTheWheel(WidgetTester tester) {
  for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final painter = paint.painter;
    if (painter is PotPainter && painter.wheel) return painter.pot;
  }
  fail('no pot on the wheel');
}

WheelSpin spinOnTheWheel(WidgetTester tester) {
  for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final painter = paint.painter;
    if (painter is PotPainter && painter.spin != null) return painter.spin!;
  }
  fail('nothing is spinning');
}

PotView viewFor(WidgetTester tester) =>
    PotView(tester.view.physicalSize / tester.view.devicePixelRatio);

void main() {
  const size = Size(393, 852);

  group('PotView', () {
    test('height round trip', () {
      final view = PotView(size);
      final pot = Pot.fresh();
      const y = 0.5;
      const theta = 0.4;
      final p = view.project(
        pot.radiusAt(y),
        y,
        math.sin(theta),
        math.cos(theta),
      );
      expect(view.heightAt(p, pot), closeTo(y, 0.02));
    });

    test('column round trip', () {
      final view = PotView(size);
      final pot = Pot.fresh();
      const y = 0.5;
      const theta = 0.4;
      final p = view.project(
        pot.radiusAt(y),
        y,
        math.sin(theta),
        math.cos(theta),
      );
      expect(
        view.columnAt(p, pot, y, 0),
        (theta / (2 * math.pi) * kCols).round(),
      );
    });

    test('column ignores how far the wheel has turned', () {
      final view = PotView(size);
      final pot = Pot.fresh();
      const y = 0.5;
      const spin = 1.2;
      final still =
          view.project(pot.radiusAt(y), y, math.sin(0.3), math.cos(0.3));
      final spun = view.project(
        pot.radiusAt(y),
        y,
        math.sin(0.3 + spin),
        math.cos(0.3 + spin),
      );
      expect(
        view.columnAt(spun, pot, y, spin),
        view.columnAt(still, pot, y, 0),
      );
    });

    test('hit test covers the wall and nothing else', () {
      final view = PotView(size);
      final pot = Pot.fresh();
      final onWall = view.project(pot.radiusAt(0.5), 0.5, 0, 1);

      expect(view.hitsPot(onWall, pot), isTrue);
      expect(view.hitsPot(onWall + const Offset(140, 0), pot), isFalse);
      expect(view.hitsPot(Offset(view.cx, 20), pot), isFalse);
      expect(view.hitsPot(Offset(view.cx, size.height - 20), pot), isFalse);
    });
  });

  group('WheelSpin', () {
    test('motor pulls a flick back to throwing speed', () {
      final wheel = WheelSpin();
      wheel.release(10);
      for (var i = 0; i < 240; i++) {
        wheel.advance(1 / 60);
      }
      expect(wheel.velocity, closeTo(WheelSpin.motorSpeed, 0.05));
    });

    test('coasts to a stop with the motor off', () {
      final wheel = WheelSpin()..setMotor(false);
      wheel.release(6);
      for (var i = 0; i < 600; i++) {
        wheel.advance(1 / 60);
      }
      expect(wheel.velocity, 0);
    });

    test('a hand on the head overrides the motor', () {
      final wheel = WheelSpin()..grab();
      wheel.turnBy(1.0);
      final held = wheel.angle;
      wheel.advance(1 / 60);
      expect(wheel.angle, held);

      wheel.release(0);
      for (var i = 0; i < 10; i++) {
        wheel.advance(1 / 60);
      }
      expect(wheel.angle, greaterThan(held));
    });

    test('flings are capped', () {
      final wheel = WheelSpin()..release(9999);
      expect(wheel.velocity, lessThan(20));
    });

    test('angle stays wrapped', () {
      final wheel = WheelSpin();
      for (var i = 0; i < 6000; i++) {
        wheel.advance(1 / 60);
      }
      expect(wheel.angle, inInclusiveRange(0, 2 * math.pi));
    });
  });

  group('Pot', () {
    test('push widens the wall only where it was touched', () {
      final pot = Pot.fresh();
      final before = List<double>.of(pot.profile);
      pot.push(y: 0.5, delta: 0.02);

      final mid = (kRows * 0.5).round();
      expect(pot.profile[mid], greaterThan(before[mid]));
      expect(pot.profile[0], closeTo(before[0], 0.002));
      expect(pot.profile[kRows], closeTo(before[kRows], 0.002));
    });

    test('radius stays within limits', () {
      final pot = Pot.fresh();
      for (var i = 0; i < 60; i++) {
        pot.push(y: 0.5, delta: -0.05);
        pot.push(y: 0.2, delta: 0.05);
      }
      for (final r in pot.profile) {
        expect(r, inInclusiveRange(kMinRadius, kMaxRadius));
      }
    });

    test('glaze lands on the cell it was poured on', () {
      final pot = Pot.fresh();
      const cobalt = 0xFF2B3BE0;
      pot.glazeSplat(y: 0.5, col: 10, argb: cobalt);

      final row = (kRows * 0.5).round();
      int blueAt(int col) => pot.glaze[row * kCols + col] & 0xFF;

      expect(blueAt(10), greaterThan(0xC0));
      expect(blueAt(12), inExclusiveRange(0x5C, blueAt(10)));
      expect(pot.glaze[row * kCols + 26], kNoGlaze);
      expect(pot.glaze[0], kNoGlaze);
    });

    test('a second pass deepens the glaze', () {
      final pot = Pot.fresh();
      const cobalt = 0xFF2B3BE0;
      final row = (kRows * 0.5).round();

      pot.glazeSplat(y: 0.5, col: 10, argb: cobalt);
      final first = pot.glaze[row * kCols + 10] & 0xFF;
      pot.glazeSplat(y: 0.5, col: 10, argb: cobalt);
      expect(pot.glaze[row * kCols + 10] & 0xFF, greaterThan(first));
    });

    test('glaze wraps across the seam', () {
      final pot = Pot.fresh();
      pot.glazeSplat(y: 0.5, col: 0, argb: 0xFF2B3BE0);
      final row = (kRows * 0.5).round();
      expect(pot.glaze[row * kCols + kCols - 1], isNot(kNoGlaze));
    });

    test('json round trip', () {
      final pot = Pot.fresh();
      pot.push(y: 0.4, delta: 0.03);
      pot.glazeSplat(y: 0.6, col: 20, argb: 0xFFFF3D9A);

      final back = Pot.tryFromJson(pot.toJson())!;
      expect(back.id, pot.id);
      expect(back.profile, pot.profile);
      expect(back.glaze, pot.glaze);
    });

    test('undo restores shape and glaze', () {
      final pot = Pot.fresh();
      final mark = pot.snapshot();
      pot.push(y: 0.5, delta: 0.05);
      pot.glazeSplat(y: 0.5, col: 4, argb: 0xFF2E2320);
      pot.restore(mark);
      expect(pot.profile, mark.profile);
      expect(pot.glaze.every((c) => c == kNoGlaze), isTrue);
    });
  });

  group('studio', () {
    testWidgets('dragging outward pulls the wall out', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StudioScreen()));
      await tester.pump();

      final pot = potOnTheWheel(tester);
      final before = List<double>.of(pot.profile);
      final view = viewFor(tester);

      final grab = view.project(pot.radiusAt(0.5), 0.5, 1, 0);
      await tester.dragFrom(grab, const Offset(30, 0));
      await tester.pump();

      final mid = (kRows * 0.5).round();
      expect(pot.profile[mid], greaterThan(before[mid]));
    });

    testWidgets('dragging beside the pot turns it', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StudioScreen()));
      await tester.pump();

      final pot = potOnTheWheel(tester);
      final before = List<double>.of(pot.profile);
      final view = viewFor(tester);
      final spin = spinOnTheWheel(tester);
      final angleBefore = spin.angle;

      await tester.dragFrom(
        Offset(view.cx + view.scale * 0.9, view.baseY),
        const Offset(60, 0),
      );
      await tester.pump();

      expect(spin.angle, isNot(angleBefore));
      expect(pot.profile, before);
      expect(pot.glaze.every((c) => c == kNoGlaze), isTrue);
    });

    testWidgets('the brush glazes without moving clay', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StudioScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.brush_rounded));
      await tester.pump();

      final pot = potOnTheWheel(tester);
      final before = List<double>.of(pot.profile);
      final view = viewFor(tester);

      final start = view.project(pot.radiusAt(0.5), 0.5, 0, 1);
      await tester.dragFrom(start, const Offset(0, -40));
      await tester.pump();

      expect(pot.glaze.any((c) => c != kNoGlaze), isTrue);
      expect(pot.profile, before);
    });
  });
}
