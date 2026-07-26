import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:setu_core/setu_core.dart';

/// A guided breathing exercise.
///
/// The wellness screen offered "Meditation — calm your mind for 10 minutes"
/// on a card that did nothing. Guided meditation proper needs a recorded voice
/// and a licence; paced breathing needs neither, works offline, and is the one
/// relaxation technique with a plainly visible mechanism — you follow a circle.
///
/// The pacing is 4 in, 4 hold, 6 out. The longer out-breath is the active
/// ingredient rather than a stylistic choice: exhaling for longer than you
/// inhale is what shifts the balance towards the calming half of the nervous
/// system. It is deliberately gentler than the popular 4-7-8 pattern, whose
/// seven-second hold leaves a lot of older people short of breath and anxious,
/// which is the opposite of the point.
///
/// No claims are made about blood pressure or sleep. It is a breathing
/// exercise, the screen says so, and anyone who wants medical advice is
/// pointed at their clinician everywhere else in this app.
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

enum _Phase { inhale, hold, exhale }

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  static const _inhale = Duration(seconds: 4);
  static const _hold = Duration(seconds: 4);
  static const _exhale = Duration(seconds: 6);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _inhale,
  );

  Timer? _ticker;
  Duration _remaining = Duration.zero;
  Duration _chosen = const Duration(minutes: 3);
  _Phase _phase = _Phase.inhale;
  bool _running = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _remaining = _chosen;
      _phase = _Phase.inhale;
    });
    _runPhase(_Phase.inhale);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _finish();
      } else {
        setState(() => _remaining = next);
      }
    });
  }

  void _finish() {
    _ticker?.cancel();
    _controller.stop();
    if (!mounted) return;
    setState(() {
      _running = false;
      _remaining = Duration.zero;
    });
  }

  void _runPhase(_Phase phase) {
    if (!mounted || !_running) return;
    setState(() => _phase = phase);
    // A light tap at each change, so someone who closes their eyes — which is
    // the natural thing to do — can still follow the rhythm without looking.
    HapticFeedback.selectionClick();

    if (phase == _Phase.inhale) {
      _controller.duration = _inhale;
      _controller.forward(from: 0).whenComplete(() => _runPhase(_Phase.hold));
      return;
    }
    if (phase == _Phase.hold) {
      Future<void>.delayed(_hold, () => _runPhase(_Phase.exhale));
      return;
    }
    _controller.duration = _exhale;
    _controller.reverse(from: 1).whenComplete(() => _runPhase(_Phase.inhale));
  }

  String get _label => switch (_phase) {
        _Phase.inhale => 'Breathe in',
        _Phase.hold => 'Hold',
        _Phase.exhale => 'Breathe out',
      };

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Breathing')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          child: Column(
            children: [
              Text(
                _running
                    ? 'Follow the circle. Let your shoulders drop.'
                    : 'A few slow breaths. Nothing to get right.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: SetuColors.mutedLight, fontSize: 16, height: 1.5),
              ),
              const Spacer(),
              Semantics(
                liveRegion: true,
                label: _running ? _label : 'Ready to begin',
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    // 0.55 → 1.0 of the available box. Never shrinks to
                    // nothing: a circle that vanishes reads as "stop", and
                    // the out-breath is not a stop.
                    final scale = 0.55 + (_controller.value * 0.45);
                    return SizedBox(
                      height: 260,
                      child: Center(
                        child: Container(
                          width: 240 * scale,
                          height: 240 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SetuColors.accentLight
                                .withValues(alpha: 0.10 + 0.10 * _controller.value),
                            border: Border.all(
                                color: SetuColors.accentLight
                                    .withValues(alpha: 0.45),
                                width: 2),
                          ),
                          child: Center(
                            child: Text(
                              _running ? _label : 'Ready',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: SetuColors.accentLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: SetuSpacing.lg),
              if (_running)
                Text(
                  '$minutes:${seconds.toString().padLeft(2, '0')} left',
                  style: const TextStyle(
                      fontSize: 18, color: SetuColors.mutedLight),
                )
              else
                Wrap(
                  spacing: SetuSpacing.sm,
                  children: [
                    for (final m in [2, 3, 5, 10])
                      ChoiceChip(
                        label: Text('$m min'),
                        selected: _chosen.inMinutes == m,
                        onSelected: (_) =>
                            setState(() => _chosen = Duration(minutes: m)),
                      ),
                  ],
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _running ? _finish : _start,
                  icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                  label: Text(_running ? 'Finish' : 'Begin'),
                ),
              ),
              const SizedBox(height: SetuSpacing.sm),
              const Text(
                'A breathing exercise, not medical treatment. If you feel '
                'dizzy or short of breath, stop and rest.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: SetuColors.mutedLight, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
