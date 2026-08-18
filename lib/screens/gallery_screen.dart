import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/palette.dart';
import '../model/pot.dart';
import '../render/pot_painter.dart';
import '../store/pot_store.dart';
import '../widgets/frost.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBackdropTop, kBackdropBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FrostButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    FrostButton(
                      icon: Icons.add_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop(Pot.fresh());
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: PotStore.instance,
                  builder: (context, _) {
                    final pots = PotStore.instance.pots;
                    if (pots.isEmpty) {
                      return Center(
                        child: Text(
                          'no pieces yet',
                          style: TextStyle(
                            color: kInk.withValues(alpha: 0.45),
                            fontSize: 14,
                          ),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: pots.length,
                      itemBuilder: (context, i) => _ShelfTile(pot: pots[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({required this.pot});

  final Pot pot;

  Future<void> _confirmDelete(BuildContext context) async {
    unawaited(HapticFeedback.mediumImpact());
    final drop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kBackdropTop,
        title: const Text('Delete this piece?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (drop ?? false) await PotStore.instance.delete(pot.id);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(pot.duplicate(id: pot.id)),
      onLongPress: () => _confirmDelete(context),
      child: CustomPaint(
        painter: PotPainter(pot: pot, angle: 0.55, wheel: false),
      ),
    );
  }
}
