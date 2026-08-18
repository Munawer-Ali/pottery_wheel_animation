import 'dart:math' as math;

import 'package:flutter/foundation.dart';

class WheelSpin extends ChangeNotifier {
  static const double motorSpeed = 2 * math.pi / 7;
  static const double _motorPull = 2.2;
  static const double _friction = 1.4;
  static const double _maxFling = 14.0;

  double angle = 0;
  double velocity = motorSpeed;
  bool motorOn = true;
  bool _handOn = false;

  bool get turningByHand => _handOn;

  void grab() {
    _handOn = true;
  }

  void turnBy(double radians) {
    if (radians == 0) return;
    angle = (angle + radians) % (2 * math.pi);
    notifyListeners();
  }

  void release(double flingVelocity) {
    _handOn = false;
    velocity = flingVelocity.clamp(-_maxFling, _maxFling);
  }

  void setMotor(bool on) {
    motorOn = on;
    notifyListeners();
  }

  void advance(double dt) {
    if (_handOn) return;
    final before = angle;
    angle = (angle + velocity * dt) % (2 * math.pi);
    if (motorOn) {
      velocity += (motorSpeed - velocity) * math.min(1.0, _motorPull * dt);
    } else {
      velocity *= math.exp(-_friction * dt);
      if (velocity.abs() < 0.01) velocity = 0;
    }
    if (angle != before) notifyListeners();
  }
}
