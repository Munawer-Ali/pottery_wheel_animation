import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../model/palette.dart';

class Frost extends StatelessWidget {
  const Frost({super.key, required this.child, this.radius = 20});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class FrostButton extends StatelessWidget {
  const FrostButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Frost(
        radius: size / 2,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: 20,
            color: kInk.withValues(alpha: enabled ? 0.75 : 0.25),
          ),
        ),
      ),
    );
  }
}
