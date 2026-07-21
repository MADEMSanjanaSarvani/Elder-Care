import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../data/trips_repository.dart';

/// Opens the caregiver's live location (with directions to the elder's home
/// when known) in the phone's Google Maps app — no in-app map SDK needed.
Future<void> _openInGoogleMaps(CaregiverTrip trip) async {
  final cur = (trip.currentLat != null && trip.currentLng != null)
      ? '${trip.currentLat},${trip.currentLng}'
      : null;
  final dest = (trip.destinationLat != null && trip.destinationLng != null)
      ? '${trip.destinationLat},${trip.destinationLng}'
      : null;
  final Uri uri;
  if (cur != null && dest != null) {
    uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$cur&destination=$dest&travelmode=driving');
  } else if (cur != null) {
    uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$cur');
  } else if (dest != null) {
    uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$dest');
  } else {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Live stream of the trip for a booking — the family's "on the way" view.
final tripProvider =
    StreamProvider.family<CaregiverTrip?, String>((ref, bookingId) {
  ref.watch(authStateProvider);
  return TripsRepository(ref.watch(supabaseClientProvider)).watch(bookingId);
});

/// The family's live tracking screen: watch the caregiver come to the door,
/// Uber-style, with a status stepper, ETA and rough distance. No map SDK —
/// this stays reliable with zero API keys; the status + distance carry the
/// reassurance.
class TripTrackingScreen extends ConsumerWidget {
  const TripTrackingScreen({
    required this.bookingId,
    this.caregiverName,
    super.key,
  });

  final String bookingId;
  final String? caregiverName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripProvider(bookingId));
    final who = caregiverName ?? 'Your caregiver';

    return Scaffold(
      appBar: AppBar(title: const Text('Live tracking')),
      body: async.when(
        loading: () => const SetuLoading(),
        error: (e, _) => const SetuErrorState(),
        data: (trip) {
          if (trip == null || trip.status == TripStatus.cancelled) {
            return SetuEmptyState(
              icon: Icons.directions_car_outlined,
              title: '$who hasn\'t set off yet',
              message:
                  'When they start heading over, you\'ll see them on their '
                  'way here in real time.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              _StatusHero(trip: trip, who: who),
              if ((trip.currentLat != null && trip.currentLng != null) ||
                  (trip.destinationLat != null &&
                      trip.destinationLng != null)) ...[
                const SizedBox(height: SetuSpacing.md),
                FilledButton.icon(
                  onPressed: () => _openInGoogleMaps(trip),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Open in Google Maps'),
                ),
              ],
              const SizedBox(height: SetuSpacing.lg),
              _StatusSteps(status: trip.status),
              if (trip.updatedAt != null) ...[
                const SizedBox(height: SetuSpacing.lg),
                Center(
                  child: Text('Updated ${_ago(trip.updatedAt!)}',
                      style: const TextStyle(
                          color: SetuColors.mutedLight, fontSize: 12.5)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 45) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.trip, required this.who});
  final CaregiverTrip trip;
  final String who;

  @override
  Widget build(BuildContext context) {
    final (headline, sub) = switch (trip.status) {
      TripStatus.enRoute => ('$who is on the way', _etaLine(trip)),
      TripStatus.arrived => ('$who has arrived', 'At the door now.'),
      TripStatus.completed => ('Visit completed', 'They\'ve finished the visit.'),
      TripStatus.cancelled => ('Trip cancelled', ''),
    };
    final color = trip.status == TripStatus.completed
        ? SetuColors.verifiedLight
        : SetuColors.accentLight;
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          SetuIconChip(
            icon: trip.status == TripStatus.arrived
                ? Icons.doorbell_outlined
                : trip.status == TripStatus.completed
                    ? Icons.check_circle_outline
                    : Icons.directions_car_filled_outlined,
            color: color,
            size: 26,
          ),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(color: SetuColors.mutedLight)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _etaLine(CaregiverTrip trip) {
    final parts = <String>[];
    if (trip.etaMinutes != null) parts.add('about ${trip.etaMinutes} min away');
    final km = trip.distanceKm;
    if (km != null) {
      parts.add(km < 1 ? 'nearly there' : '≈${km.toStringAsFixed(1)} km away');
    }
    return parts.isEmpty ? 'Heading to you now.' : parts.join(' · ');
  }
}

class _StatusSteps extends StatelessWidget {
  const _StatusSteps({required this.status});
  final TripStatus status;

  @override
  Widget build(BuildContext context) {
    final index = switch (status) {
      TripStatus.enRoute => 0,
      TripStatus.arrived => 1,
      TripStatus.completed => 2,
      TripStatus.cancelled => 0,
    };
    const labels = ['On the way', 'Arrived', 'Visit complete'];
    return Column(
      children: [
        for (var i = 0; i < labels.length; i++)
          _Step(
            label: labels[i],
            done: i < index,
            active: i == index,
            isLast: i == labels.length - 1,
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.done,
    required this.active,
    required this.isLast,
  });
  final String label;
  final bool done;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final reached = done || active;
    final color = done
        ? SetuColors.verifiedLight
        : active
            ? SetuColors.accentLight
            : SetuColors.borderLight;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: reached ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? SetuColors.verifiedLight : SetuColors.borderLight,
                  ),
                ),
            ],
          ),
          const SizedBox(width: SetuSpacing.md),
          Padding(
            padding: const EdgeInsets.only(top: 1, bottom: SetuSpacing.lg),
            child: Text(label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: reached ? SetuColors.inkLight : SetuColors.mutedLight,
                )),
          ),
        ],
      ),
    );
  }
}
