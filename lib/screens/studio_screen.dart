import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../model/palette.dart';
import '../model/pot.dart';
import '../model/wheel.dart';
import '../render/pot_painter.dart';
import '../store/pot_store.dart';
import '../widgets/frost.dart';
import 'gallery_screen.dart';

enum Tool { shape, glaze }

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen>
    with SingleTickerProviderStateMixin {
  static const int _undoDepth = 24;
  static const double _turnPerPixel = 0.35;

  final WheelSpin _wheel = WheelSpin();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  Pot _pot = Pot.fresh();
  Tool _tool = Tool.shape;
  int _glazeIndex = 0;
  bool _paletteOpen = false;
  bool _showHint = true;
  bool _grabbedClay = false;
  final List<PotSnapshot> _undo = <PotSnapshot>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
      _lastTick = elapsed;
      if (dt > 0 && dt < 0.25) _wheel.advance(dt);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _wheel.dispose();
    super.dispose();
  }

  void _beginStroke() {
    _undo.add(_pot.snapshot());
    if (_undo.length > _undoDepth) _undo.removeAt(0);
  }

  void _onDragStart(DragStartDetails d, PotView view) {
    if (_showHint) setState(() => _showHint = false);
    _grabbedClay = view.hitsPot(d.localPosition, _pot);
    if (_grabbedClay) {
      _beginStroke();
    } else {
      _wheel.grab();
    }
  }

  void _onDrag(DragUpdateDetails d, PotView view) {
    if (!_grabbedClay) {
      _wheel.turnBy(d.delta.dx / (view.scale * _turnPerPixel));
      return;
    }
    final y = view.heightAt(d.localPosition, _pot);
    if (_tool == Tool.shape) {
      final side = d.localPosition.dx >= view.cx ? 1.0 : -1.0;
      final delta = (d.delta.dx / view.scale * side).clamp(-0.02, 0.02);
      _pot.push(y: y, delta: delta);
    } else {
      final col = view.columnAt(d.localPosition, _pot, y, _wheel.angle);
      _pot.glazeSplat(
        y: y,
        col: col,
        argb: kGlazes[_glazeIndex].toARGB32(),
      );
    }
    setState(() {});
  }

  void _onDragEnd(DragEndDetails d, PotView view) {
    if (_grabbedClay) return;
    _wheel.release(
      d.velocity.pixelsPerSecond.dx / (view.scale * _turnPerPixel),
    );
  }

  void _toggleMotor() {
    HapticFeedback.selectionClick();
    setState(() => _wheel.setMotor(!_wheel.motorOn));
  }

  void _undoStroke() {
    if (_undo.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pot.restore(_undo.removeLast()));
  }

  void _newPiece() {
    setState(() {
      _pot = Pot.fresh();
      _undo.clear();
      _tool = Tool.shape;
    });
  }

  Future<void> _openShelf() async {
    await HapticFeedback.lightImpact();
    await PotStore.instance.save(_pot);
    if (!mounted) return;
    final picked = await Navigator.of(context).push<Pot>(
      MaterialPageRoute<Pot>(builder: (_) => const GalleryScreen()),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _pot = picked;
      _undo.clear();
    });
  }

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
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final view = PotView(constraints.biggest);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _onDragStart(d, view),
                    onPanUpdate: (d) => _onDrag(d, view),
                    onPanEnd: (d) => _onDragEnd(d, view),
                    onPanCancel: () => _wheel.release(0),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: PotPainter(pot: _pot, spin: _wheel),
                        size: Size.infinite,
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _toolPill(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, right: 16),
                      child: _glazeShelf(),
                    ),
                  ),
                  if (_showHint)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 78,
                          right: 78,
                          bottom: 90,
                        ),
                        child: Text(
                          _tool == Tool.shape
                              ? 'drag the clay to shape it\ndrag beside it to turn the wheel'
                              : 'drag to pour glaze\ndrag beside it to turn the wheel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kInk.withValues(alpha: 0.45),
                            fontSize: 13,
                            height: 1.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 18, bottom: 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FrostButton(
                            icon: Icons.undo_rounded,
                            enabled: _undo.isNotEmpty,
                            onTap: _undoStroke,
                          ),
                          const SizedBox(height: 10),
                          FrostButton(
                            icon: _wheel.motorOn
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            onTap: _toggleMotor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 18, bottom: 22),
                      child: _shelfChip(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolPill() {
    return Frost(
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toolButton(Tool.shape, Icons.back_hand_outlined),
            _toolButton(Tool.glaze, Icons.brush_rounded),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(Tool tool, IconData icon) {
    final selected = _tool == tool;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _tool = tool;
          _paletteOpen = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.45) : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          icon,
          size: 20,
          color: kInk.withValues(alpha: selected ? 0.85 : 0.42),
        ),
      ),
    );
  }

  Widget _glazeShelf() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _tool != Tool.glaze
          ? const SizedBox(width: 34, height: 34)
          : Column(
              key: const ValueKey('glazes'),
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _swatch(
                  kGlazes[_glazeIndex],
                  size: 34,
                  onTap: () => setState(() => _paletteOpen = !_paletteOpen),
                ),
                if (_paletteOpen)
                  for (var i = 0; i < kGlazes.length; i++)
                    if (i != _glazeIndex)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _swatch(
                          kGlazes[i],
                          size: 26,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _glazeIndex = i;
                              _paletteOpen = false;
                            });
                          },
                        ),
                      ),
              ],
            ),
    );
  }

  Widget _swatch(Color color, {required double size, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: kWheelEdge.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shelfChip() {
    return GestureDetector(
      onTap: _openShelf,
      onLongPress: _newPiece,
      child: Frost(
        radius: 14,
        child: SizedBox(
          width: 46,
          height: 58,
          child: CustomPaint(
            painter: PotPainter(pot: _pot, angle: 0.6, wheel: false),
          ),
        ),
      ),
    );
  }
}
