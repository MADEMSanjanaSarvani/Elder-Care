import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:setu_core/setu_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../data/sos_repository.dart';

/// PRD Part 1 §04 / Part 2 §12: "Call 108" is the mandatory primary
/// action. Platform escalation (notifying family + on-call ops) is a
/// secondary action that runs in parallel — never instead of — calling
/// emergency services. This screen's mere existence is itself the
/// "108-first screen was shown" evidence the sos-trigger function requires.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({required this.elderId, super.key});

  final String elderId;

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  bool _notifying = false;
  bool _notified = false;
  bool _drilling = false;
  String? _error;

  Future<void> _call108() async {
    await launchUrl(Uri.parse('tel:108'));
  }

  /// A practice run. Goes to the SEPARATE drill function — it never fans out
  /// a real alert to family or ops — and returns coaching feedback we show
  /// in a dialog so the elder learns the flow without any real consequence.
  Future<void> _practice() async {
    setState(() {
      _drilling = true;
      _error = null;
    });
    try {
      final feedback =
          await SosRepository(ref.read(supabaseClientProvider))
              .drill(elderId: widget.elderId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Practice complete'),
          content: Text(feedback),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _drilling = false);
    }
  }

  Future<void> _notifyPlatform() async {
    setState(() {
      _notifying = true;
      _error = null;
    });
    try {
      final position = await Geolocator.getCurrentPosition();
      final repo = SosRepository(ref.read(supabaseClientProvider));
      await repo.trigger(
        elderId: widget.elderId,
        lat: position.latitude,
        lng: position.longitude,
        ack108Shown: true, // this screen is the 108-first screen
      );
      setState(() => _notified = true);
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _notifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Emergency'),
          backgroundColor: SetuColors.sosLight,
          foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: SetuSpacing.lg),
            // The pulsing red heart of the screen: one calm, unmissable tap
            // that dials 108. Everything else is deliberately quieter.
            Center(child: _PulsingCallButton(onTap: _call108)),
            const SizedBox(height: SetuSpacing.xl),
            Text(
              'Tap the button to call 108 — the fastest way to get emergency '
              'medical help.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(height: 1.4),
            ),
            const SizedBox(height: SetuSpacing.xl),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(SetuSpacing.md),
                decoration: BoxDecoration(
                  color: SetuColors.sosLight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
              const SizedBox(height: SetuSpacing.md),
            ],
            if (_notified)
              Container(
                padding: const EdgeInsets.all(SetuSpacing.md),
                decoration: BoxDecoration(
                  color: SetuColors.verifiedLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: SetuColors.verifiedLight),
                    SizedBox(width: SetuSpacing.sm),
                    Expanded(
                      child: Text(
                          'Your family and our on-call team have been notified.'),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: SetuSpacing.md),
                ),
                onPressed: _notifying ? null : _notifyPlatform,
                icon: _notifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.notifications_active_outlined),
                label: Text(
                    _notifying ? 'Notifying…' : 'Also notify family & CareHive'),
              ),
            const SizedBox(height: SetuSpacing.sm),
            Text(
              'Notifying CareHive alerts your family and our on-call team at the '
              'same time — it does not replace calling 108.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: SetuColors.mutedLight),
            ),
            const SizedBox(height: SetuSpacing.xl),
            const Divider(),
            TextButton.icon(
              onPressed: _drilling ? null : _practice,
              icon: const Icon(Icons.school_outlined),
              label: Text(_drilling
                  ? 'Running practice…'
                  : 'Practice this (no real alert)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The primary emergency control: a large circular "Call 108" button that
/// breathes with a soft red halo so it draws the eye without shouting.
/// Honours reduced-motion (renders a still button with a static ring).
class _PulsingCallButton extends StatefulWidget {
  const _PulsingCallButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PulsingCallButton> createState() => _PulsingCallButtonState();
}

class _PulsingCallButtonState extends State<_PulsingCallButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _button() => Material(
        color: SetuColors.sosLight,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: SetuColors.sosLight.withValues(alpha: 0.6),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          child: const SizedBox(
            width: 200,
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call, size: 56, color: Colors.white),
                SizedBox(height: SetuSpacing.sm),
                Text('Call 108',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text('Emergency',
                    style: TextStyle(fontSize: 15, color: Colors.white)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    Widget halo(double t) => Container(
          width: 200 + t * 56,
          height: 200 + t * 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SetuColors.sosLight.withValues(alpha: 0.18 * (1 - t)),
          ),
        );
    if (reduce) {
      return SizedBox(
        width: 256,
        height: 256,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [halo(0.5), _button()],
          ),
        ),
      );
    }
    return SizedBox(
      width: 256,
      height: 256,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [halo(_c.value), _button()],
        ),
      ),
    );
  }
}
