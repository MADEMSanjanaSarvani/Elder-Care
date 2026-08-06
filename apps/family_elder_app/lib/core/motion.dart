/// The feedback that tells somebody their tap landed.
///
/// CareHive asks one thing of people, several times a day, for years: press
/// Taken. Before this, that press did nothing visible — an async call went out
/// and, a network round-trip later, the card silently re-rendered into a
/// different shape. On a slow connection that is a second or more of a screen
/// that looks broken, and the honest reaction is to press it again.
///
/// So every helper here exists to answer one question — *did that work?* —
/// immediately, before the server has been asked.
///
/// ## Reduce motion is obeyed, not decorated around
///
/// Every duration here collapses to zero when the OS asks for reduced motion.
/// That setting is used by people who get motion sickness or vestibular
/// symptoms from animation, and this is a health app for older people, which
/// is exactly the population that turns it on. The end states are all identical
/// with motion off — nothing is *only* communicated by movement, so nothing is
/// lost. Colour and the check mark still change; they just change instantly.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Standard timings. Short: this is feedback, not choreography, and an elder
/// tapping four doses in a row should not wait on four animations.
abstract final class Motion {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);

  /// [d], or nothing at all if the OS asked for reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : d;
}

/// A short buzz for a tap that changed something real.
///
/// Deliberately not on navigation or scrolling — a phone that vibrates
/// constantly gets its haptics turned off, and then the one buzz that means
/// "your medicine is recorded" is gone too. Failures are silent by design:
/// Android throws here when the device has no vibrator or the app lacks the
/// permission, and an error report about a missing buzz would be noise.
abstract final class Buzz {
  static void tap() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// For a dose recorded — the one moment in the app worth feeling.
  static void confirm() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static void warn() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}

/// Sinks slightly under the finger, springs back on release.
///
/// The cheapest possible "this is a thing you can press", and it works without
/// reading anything — which matters more here than on most apps.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// How far it sinks. Kept shallow — a card that visibly shrinks reads as
  /// broken rather than responsive.
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              Buzz.tap();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: Motion.of(context, Motion.fast),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A tick that draws itself on, then settles.
///
/// Used the moment a dose is recorded. It is the only celebratory thing in
/// CareHive and it is deliberately small: a dose taken on time is normal, not
/// an achievement, and confetti would turn an honest record into a game people
/// start playing rather than telling the truth to.
class CheckPop extends StatefulWidget {
  const CheckPop({required this.color, this.size = 26, super.key});

  final Color color;
  final double size;

  @override
  State<CheckPop> createState() => _CheckPopState();
}

class _CheckPopState extends State<CheckPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      // Overshoots a little and settles — the shape of something landing.
      scale: Tween<double>(begin: 0.4, end: 1.0)
          .animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut)),
      child: Icon(Icons.check_circle_rounded,
          color: widget.color, size: widget.size),
    );
  }
}

/// Counts from the previous value to the new one.
///
/// On the Today header, so "2 of 5 marked" becoming "3 of 5" is something you
/// see happen rather than something that was silently already true.
class CountUp extends StatelessWidget {
  const CountUp({required this.value, required this.style, super.key});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: Motion.of(context, Motion.normal),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}
