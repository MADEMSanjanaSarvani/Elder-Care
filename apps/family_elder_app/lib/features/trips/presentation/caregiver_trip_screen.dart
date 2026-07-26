import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location.dart';
import '../../../core/providers.dart';
import '../data/trips_repository.dart';
import 'trip_tracking_screen.dart';

/// The caregiver's live-trip controls for a booking: go on the way (which
/// starts streaming their location to the family), open turn-by-turn
/// navigation in their maps app, and mark arrival. Location only streams
/// while this trip is active — it stops the moment they arrive or leave.
class CaregiverTripScreen extends ConsumerStatefulWidget {
  const CaregiverTripScreen({required this.bookingId, super.key});
  final String bookingId;

  @override
  ConsumerState<CaregiverTripScreen> createState() =>
      _CaregiverTripScreenState();
}

class _CaregiverTripScreenState extends ConsumerState<CaregiverTripScreen> {
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  TripsRepository get _repo =>
      TripsRepository(ref.read(supabaseClientProvider));

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _startTrip() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.start(widget.bookingId);
      await _pushOnce();
      _ticker?.cancel();
      // A light foreground heartbeat — good enough for a short door-to-door
      // trip without the battery cost (or Play review) of background location.
      _ticker = Timer.periodic(
          const Duration(seconds: 20), (_) => _pushOnce());
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pushOnce() async {
    try {
      // A live fix only: pushing a stale position would tell the family the
      // caregiver is somewhere they left an hour ago, which is worse than
      // showing nothing. A missed ping is fine; the next tick catches up.
      final located = await captureLocation(
        accuracy: LocationAccuracy.high,
        timeout: const Duration(seconds: 20),
        allowStale: false,
      );
      final pos = located.position;
      if (pos == null) return;
      await _repo.pushLocation(widget.bookingId,
          lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      // A single missed ping is fine; the next tick will catch up.
    }
  }

  Future<void> _navigate(CaregiverTrip? trip) async {
    final lat = trip?.destinationLat;
    final lng = trip?.destinationLng;
    final Uri uri = (lat != null && lng != null)
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=');
    if (lat == null || lng == null) {
      setState(() => _error =
          'No saved location for this member yet — ask the family to set it.');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      setState(() => _error = 'Could not open maps.');
    }
  }

  Future<void> _markArrived() async {
    setState(() => _busy = true);
    try {
      await _repo.setStatus(widget.bookingId, TripStatus.arrived);
      _ticker?.cancel();
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripProvider(widget.bookingId));
    final trip = async.asData?.value;
    final status = trip?.status;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip to visit')),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          if (status == null || status == TripStatus.cancelled)
            _card(
              icon: Icons.directions_car_filled_outlined,
              title: 'Ready to head over?',
              body:
                  'Let the family know you\'re on the way. They\'ll see you '
                  'coming, and your location is shared only until you arrive.',
            )
          else if (status == TripStatus.enRoute)
            _card(
              icon: Icons.navigation_outlined,
              title: 'You\'re on the way',
              body:
                  'The family can see you approaching. Open navigation, and '
                  'tap "I\'ve arrived" when you reach the door.',
              color: SetuColors.accentLight,
            )
          else
            _card(
              icon: Icons.check_circle_outline,
              title: 'You\'ve arrived',
              body: 'Head in and start the visit with the family\'s code.',
              color: SetuColors.verifiedLight,
            ),
          const SizedBox(height: SetuSpacing.lg),
          if (_error != null) ...[
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: SetuSpacing.md),
          ],
          if (status == null || status == TripStatus.cancelled)
            FilledButton.icon(
              onPressed: _busy ? null : _startTrip,
              icon: const Icon(Icons.send_outlined),
              label: const Text('I\'m on my way'),
            ),
          if (status == TripStatus.enRoute) ...[
            FilledButton.icon(
              onPressed: _busy ? null : () => _navigate(trip),
              icon: const Icon(Icons.navigation),
              label: const Text('Start navigation'),
            ),
            const SizedBox(height: SetuSpacing.sm),
            OutlinedButton.icon(
              onPressed: _busy ? null : _markArrived,
              icon: const Icon(Icons.doorbell_outlined),
              label: const Text('I\'ve arrived'),
            ),
          ],
          if (status == TripStatus.arrived)
            FilledButton.icon(
              onPressed: () => context.push('/booking/${widget.bookingId}'),
              icon: const Icon(Icons.key_outlined),
              label: const Text('Enter visit code'),
            ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String body,
    Color color = SetuColors.mutedLight,
  }) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SetuIconChip(icon: icon, color: color, size: 24),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        color: SetuColors.mutedLight, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
