import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:setu_core/setu_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location.dart';
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
  /// True when the alert went out but the phone couldn't produce a location.
  /// The confirmation screen must say so rather than claim responders can see
  /// where you are — the one place in this app where a reassuring lie could
  /// get somebody hurt.
  bool _locationMissing = false;
  bool _cancelling = false;
  bool _cancelled = false;

  /// The row `sos-trigger` created, so it can be stood back down. Held only
  /// for this screen's lifetime — a cancel after the app has been closed goes
  /// through the on-call operator, which is the right escalation for that.
  String? _sosEventId;
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
      // The alert goes out whether or not the phone can find itself.
      //
      // This used to call getCurrentPosition() with no timeout at all, and a
      // failure took the whole SOS down with it — so an elder indoors, or with
      // location switched off, pressed the emergency button and nothing
      // happened. A location is extremely useful here and it is not worth more
      // than the alert itself: knowing something is wrong with no coordinates
      // beats knowing nothing.
      //
      // Stale is accepted for the same reason. A fix from an hour ago is
      // usually still the right building, and an operator with an approximate
      // address is far ahead of one with none.
      final result = await captureLocation(
        accuracy: LocationAccuracy.high,
        timeout: const Duration(seconds: 12),
      );
      final repo = SosRepository(ref.read(supabaseClientProvider));
      final event = await repo.trigger(
        elderId: widget.elderId,
        lat: result.position?.latitude,
        lng: result.position?.longitude,
        ack108Shown: true, // this screen is the 108-first screen
      );
      setState(() {
        _notified = true;
        _locationMissing = !result.ok;
        _sosEventId = event['id'] as String?;
      });
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _notifying = false);
    }
  }

  /// Stands the alert back down after a mis-tap.
  ///
  /// Confirmed first, and deliberately not with a "Yes/No" pair: the two
  /// wrong outcomes here are wildly asymmetric. Cancelling a real emergency by
  /// accident is a catastrophe; leaving a false alarm running for another
  /// thirty seconds is an embarrassment. So the confirming button carries the
  /// whole sentence and the safe option is the one your thumb finds first.
  Future<void> _cancelAlert() async {
    final id = _sosEventId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this emergency?'),
        content: const Text(
          'Your family and the SETU team will be told it was a false alarm. '
          'Only do this if nobody needs help.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep the alert'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, it was a false alarm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _cancelling = true;
      _error = null;
    });
    try {
      await SosRepository(ref.read(supabaseClientProvider))
          .cancel(sosEventId: id);
      if (mounted) setState(() => _cancelled = true);
    } catch (err) {
      // Says plainly that the alert is still live. Anything vaguer and someone
      // walks away believing they stood it down when they didn't.
      if (mounted) {
        setState(() => _error =
            'Could not cancel — the alert is still active. Please call your '
            'family directly. ($err)');
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
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
            if (_cancelled) ...[
              // The stood-down state. It says who was told, because the
              // question immediately after cancelling is "do I still need to
              // ring my daughter?" and the answer is no.
              Container(
                padding: const EdgeInsets.all(SetuSpacing.lg),
                decoration: BoxDecoration(
                  color: SetuColors.verifiedLight.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: SetuColors.verifiedLight.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: SetuColors.verifiedLight, size: 44),
                    const SizedBox(height: SetuSpacing.sm),
                    Text('Alert cancelled',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                color: SetuColors.verifiedLight,
                                fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'Your family and the SETU team have been told it was a '
                      'false alarm. Nobody is on their way.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SetuColors.mutedLight),
                    ),
                  ],
                ),
              ),
            ] else if (_notified) ...[
              // Matches the Stitch "emergency_sos_active" badge treatment.
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: SetuColors.sosLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: SetuColors.sosLight.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Center(
                    child: Text('SOS',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1)),
                  ),
                ),
              ),
              const SizedBox(height: SetuSpacing.md),
              Text('Emergency Mode Activated',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: SetuColors.sosLight, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Help is on the way. Please stay calm.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SetuColors.mutedLight)),
              const SizedBox(height: SetuSpacing.lg),
              // "Location shared" strip — the real trigger() call already sent
              // the coordinates; this isn't a live map, just confirmation that
              // it happened (no fabricated street address).
              //
              // When the fix failed it says so instead. Telling someone in an
              // emergency that responders can see where they are, when nobody
              // can, is the single worst lie this app could tell.
              Container(
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _locationMissing
                        ? [
                            SetuColors.peachLight.withValues(alpha: 0.18),
                            SetuColors.paperLight,
                          ]
                        : [
                            SetuColors.verifiedLight.withValues(alpha: 0.16),
                            SetuColors.accentLight.withValues(alpha: 0.10),
                          ],
                  ),
                  border: Border.all(color: SetuColors.borderLight),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: SetuSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: _locationMissing
                              ? SetuColors.peachLight
                              : SetuColors.verifiedLight,
                          shape: BoxShape.circle),
                      child: Icon(
                          _locationMissing
                              ? Icons.location_off_outlined
                              : Icons.my_location,
                          color: Colors.white,
                          size: 20),
                    ),
                    const SizedBox(width: SetuSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              _locationMissing
                                  ? 'Location not available'
                                  : 'Live location sharing',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                              _locationMissing
                                  ? 'Tell them where you are when they call'
                                  : 'Responders can see where you are',
                              style: const TextStyle(
                                  color: SetuColors.mutedLight, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: SetuSpacing.md),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _locationMissing
                            ? SetuColors.peachLight
                            : SetuColors.verifiedLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(_locationMissing ? 'NO GPS' : 'ACTIVE',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SetuSpacing.md),
              Container(
                padding: const EdgeInsets.all(SetuSpacing.lg),
                decoration: BoxDecoration(
                  color: SetuColors.paperRaisedLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active actions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: SetuSpacing.md),
                    _ActiveAction(
                        icon: Icons.family_restroom_outlined,
                        tint: SetuColors.lavenderLight,
                        title: 'Family notified',
                        subtitle: 'Your care circle has been alerted'),
                    _ActiveAction(
                        icon: Icons.support_agent_outlined,
                        tint: SetuColors.peachLight,
                        title: 'On-call team alerted',
                        subtitle: 'SETU is coordinating help'),
                    // Follows the same fix as the strip above rather than
                    // hardcoding success. This row used to claim the location
                    // had been shared while the strip six pixels higher said
                    // NO GPS — a direct contradiction, on the screen where
                    // being believed matters most.
                    _ActiveAction(
                        icon: _locationMissing
                            ? Icons.location_off_outlined
                            : Icons.my_location_outlined,
                        tint: _locationMissing
                            ? SetuColors.peachLight
                            : SetuColors.accentLight,
                        done: !_locationMissing,
                        title: _locationMissing
                            ? 'Location not sent'
                            : 'Location shared',
                        subtitle: _locationMissing
                            ? 'The phone could not get a fix'
                            : 'Responders can find you'),
                  ],
                ),
              ),
              const SizedBox(height: SetuSpacing.md),
              Container(
                padding: const EdgeInsets.all(SetuSpacing.lg),
                decoration: BoxDecoration(
                  color: SetuColors.accentLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.headset_mic_outlined,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('AI DISPATCHER',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6)),
                      ],
                    ),
                    const SizedBox(height: SetuSpacing.sm),
                    const Text(
                      'We\'re keeping your line open. If you can speak, tell us '
                      'what happened. Otherwise, just keep breathing deeply.',
                      style: TextStyle(color: Colors.white, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SetuSpacing.lg),
              // The undo. Until this existed a pocket-press sent the whole
              // care circle across the city with no way to call them back,
              // and every false alarm made the next real one less believed.
              //
              // Outlined, not filled: it must be findable without competing
              // with anything on the screen that is actually about getting
              // help.
              if (_sosEventId != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: SetuSpacing.md),
                    foregroundColor: SetuColors.mutedLight,
                    side: const BorderSide(
                        color: SetuColors.borderLight, width: 2),
                  ),
                  onPressed: _cancelling ? null : _cancelAlert,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined),
                  label: Text(_cancelling
                      ? 'Cancelling…'
                      : 'Cancel — it was a false alarm'),
                ),
            ] else
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
                    _notifying ? 'Notifying…' : 'Also notify family & SETU'),
              ),
            const SizedBox(height: SetuSpacing.sm),
            Text(
              'Notifying SETU alerts your family and our on-call team at the '
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

/// One row in the active-emergency "Active actions" checklist.
class _ActiveAction extends StatelessWidget {
  const _ActiveAction({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    this.done = true,
  });
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;

  /// A green tick means it happened. A row that didn't happen gets a dash
  /// instead, so the checklist can't be read as all-clear at a glance.
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration:
                BoxDecoration(color: tint.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: const TextStyle(
                        color: SetuColors.mutedLight, fontSize: 12.5)),
              ],
            ),
          ),
          Icon(done ? Icons.check_circle : Icons.remove_circle_outline,
              color: done ? SetuColors.verifiedLight : SetuColors.peachLight,
              size: 22),
        ],
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
