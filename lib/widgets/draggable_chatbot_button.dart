import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/app_routing.dart';
import '../core/app_theme.dart';

/// The web's chatbot FAB hover ring — a conic gradient that rotates while
/// it's lit. Same stops as `.chatbot-fab-ring::before` in layouts/app.blade.php.
const _glowColors = <Color>[
  Color(0xFF4F8EF7),
  Color(0xFFA259FF),
  Color(0xFFF472B6),
  Color(0xFFFB923C),
  Color(0xFF34D399),
  Color(0xFF22D3EE),
  Color(0xFF4F8EF7),
];
const _glowStops = <double>[0.0, 0.18, 0.36, 0.52, 0.68, 0.84, 1.0];

/// Round, draggable Matcha AI launcher.
///
/// Layout only for now — [onTap] is left to the caller, so the chat itself
/// can be wired up later without touching this.
///
/// Must be placed as a direct child of a [Stack] (it returns a
/// [Positioned.fill] so it can measure the area it's allowed to move in).
/// Empty space around the button doesn't absorb touches, so whatever is
/// underneath still scrolls normally.
class DraggableChatbotButton extends StatefulWidget {
  const DraggableChatbotButton({
    super.key,
    this.onTap,
    this.size = 62,
    this.margin = 16,
    this.bottomMargin = 24,
    this.tapMaxDistance = 6,
  });

  final VoidCallback? onTap;

  /// Diameter of the circular button.
  final double size;

  /// Gap from the right edge used for the button's resting position.
  final double margin;

  /// Gap from the bottom edge used for the button's resting position.
  final double bottomMargin;

  /// How far the finger may travel and still count as a tap rather than a
  /// drag, in logical pixels.
  ///
  /// Tap is resolved here rather than with `GestureDetector.onTap` on
  /// purpose: a TapGestureRecognizer holds the gesture arena until the finger
  /// passes its own ~18px slop, and only then does the pan recognizer take
  /// over — which is exactly the "button ignores small drags" lag. With the
  /// pan recognizer alone in the arena it wins immediately, so the button
  /// tracks the finger from the first pixel.
  final double tapMaxDistance;

  @override
  State<DraggableChatbotButton> createState() => _DraggableChatbotButtonState();
}

class _DraggableChatbotButtonState extends State<DraggableChatbotButton>
    with SingleTickerProviderStateMixin, RouteAware {
  static const _glowFade = Duration(milliseconds: 350);

  /// Top-left of the button within the parent Stack. Null means "resting
  /// position" (bottom-right), which is also what we fall back to whenever
  /// the screen is revisited.
  Offset? _position;

  /// Drives the visuals (glow + scale). Only true once the finger has moved
  /// far enough to count as a drag, so a plain tap doesn't flash the ring.
  bool _isDragging = false;

  /// True for the whole pan, including the first few pixels. Used to disable
  /// position animation while dragging so the button tracks 1:1.
  bool _isPanActive = false;

  /// Total finger travel for the current gesture, used to tell a tap from a
  /// drag once the finger lifts.
  double _travel = 0;

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  /// Stops the (infinitely repeating) glow once it has faded out. Driven by a
  /// timer rather than AnimatedOpacity.onEnd: if the button is released in
  /// the same frame the glow appeared, the opacity never actually animates,
  /// onEnd never fires, and the controller would spin forever.
  Timer? _glowStopTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _glowStopTimer?.cancel();
    _glow.dispose();
    super.dispose();
  }

  /// Fired when a screen pushed on top of this one is popped — i.e. we're
  /// back. Send the button home so it never reappears somewhere unexpected.
  @override
  void didPopNext() {
    if (_position != null) setState(() => _position = null);
  }

  void _startGlow() {
    _glowStopTimer?.cancel();
    if (!_glow.isAnimating) _glow.repeat();
  }

  void _stopGlowAfterFade() {
    _glowStopTimer?.cancel();
    _glowStopTimer = Timer(_glowFade, () {
      if (mounted && !_isDragging) _glow.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxLeft = (constraints.maxWidth - widget.size).clamp(0.0, double.infinity);
          final maxTop = (constraints.maxHeight - widget.size).clamp(0.0, double.infinity);

          final current = _position ?? Offset(maxLeft - widget.margin, maxTop - widget.bottomMargin);

          // Re-clamped on every build, so the button can't end up stranded
          // off-screen when the available area shrinks (rotation, keyboard).
          final left = current.dx.clamp(0.0, maxLeft);
          final top = current.dy.clamp(0.0, maxTop);

          return Stack(
            children: [
              AnimatedPositioned(
                // Instant while a finger is down; eased when it glides back
                // to its resting spot on return to the screen.
                duration: _isPanActive ? Duration.zero : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: left,
                top: top,
                child: GestureDetector(
                  onPanDown: (_) {
                    _travel = 0;
                    _isPanActive = true;
                  },
                  onPanUpdate: (details) {
                    _travel += details.delta.distance;
                    setState(() {
                      if (_travel > widget.tapMaxDistance && !_isDragging) {
                        _isDragging = true;
                        _startGlow();
                      }
                      _position = Offset(
                        (left + details.delta.dx).clamp(0.0, maxLeft),
                        (top + details.delta.dy).clamp(0.0, maxTop),
                      );
                    });
                  },
                  onPanEnd: (_) {
                    final wasTap = _travel <= widget.tapMaxDistance;
                    setState(() {
                      _isDragging = false;
                      _isPanActive = false;
                    });
                    _stopGlowAfterFade();
                    if (wasTap) widget.onTap?.call();
                  },
                  onPanCancel: () {
                    setState(() {
                      _isDragging = false;
                      _isPanActive = false;
                    });
                    _stopGlowAfterFade();
                  },
                  child: _button(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _button() {
    return AnimatedScale(
      scale: _isDragging ? 1.08 : 1,
      duration: const Duration(milliseconds: 20),
      curve: Curves.easeOut,
      child: SizedBox(
        // Fixed to the button's own diameter so the glow, which paints
        // outside these bounds, never affects the drag maths.
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: -7, top: -7, right: -7, bottom: -7, child: _glowLayer(blur: 8)),
            Positioned(left: -4, top: -4, right: -4, bottom: -4, child: _glowLayer()),
            Positioned.fill(child: _circle()),
          ],
        ),
      ),
    );
  }

  /// One rotating conic-gradient disc. The button is painted on top of it, so
  /// only the part peeking out past the edge reads as a ring — the same trick
  /// the web's ::before / ::after pseudo-elements use.
  Widget _glowLayer({double blur = 0}) {
    Widget ring = AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => Transform.rotate(angle: _glow.value * 2 * math.pi, child: child),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: _glowColors, stops: _glowStops),
        ),
      ),
    );

    if (blur > 0) {
      ring = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: ring);
    }

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _isDragging ? 1 : 0,
        duration: _glowFade,
        child: ring,
      ),
    );
  }

  Widget _circle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDragging ? 0.35 : 0.22),
            blurRadius: _isDragging ? 18 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.size * 0.17),
        child: Image.asset('assets/ai_chatbot_logo.png', fit: BoxFit.contain),
      ),
    );
  }
}
