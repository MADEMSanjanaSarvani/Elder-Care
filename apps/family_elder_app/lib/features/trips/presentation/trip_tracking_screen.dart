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
/// reassurance, and Google Maps handles the actual map on tap.
///
/// Styled to the same language as the rest of the app: a soft route panel,
/// a bold status headline, and a dashed live-tracking treatment matching the
/// family dashboard's "caregiver on the way" card.
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
          final hasCoords = (trip.currentLat != null &&
                  trip.currentLng != null) ||
              (trip.destinationLat != null && trip.destinationLng != null);
          return ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              _RoutePanel(trip: trip),
              const SizedBox(height: SetuSpacing.lg),
              _StatusHero(trip: trip, who: who),
              if (hasCoords) ...[
                const SizedBox(height: SetuSpacing.md),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _openInGoogleMaps(trip),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open in Google Maps'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: SetuSpacing.xl),
              const Text('PROGRESS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: SetuColors.mutedLight)),
              const SizedBox(height: SetuSpacing.md),
              _StatusSteps(status: trip.status),
              if (trip.updatedAt != null) ...[
                const SizedBox(height: SetuSpacing.md),
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

/// A calm, map-flavoured panel: a soft grid, a route line from the caregiver
/// to the elder's home, and a live dot while they're moving. Decorative by
/// design — the real map is one tap away in Google Maps, and inventing a
/// fake street layout would over-claim what we actually know.
class _RoutePanel extends StatelessWidget {
  const _RoutePanel({required this.trip});
  final CaregiverTrip trip;

  @override
  Widget build(BuildContext context) {
    final arrived = trip.status != TripStatus.enRoute;
    return Container(
      height: 168,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SetuColors.borderLight),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SetuColors.verifiedLight.withValues(alpha: 0.14),
            SetuColors.accentLight.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
          // Caregiver marker (start of the route).
          Positioned(
            left: 34,
            top: 38,
            child: _Marker(
              icon: Icons.directions_car_filled_rounded,
              color: SetuColors.accentLight,
              pulsing: !arrived,
            ),
          ),
          // The elder's home (end of the route).
          const Positioned(
            right: 34,
            bottom: 38,
            child: _Marker(
              icon: Icons.home_rounded,
              color: SetuColors.verifiedLight,
              pulsing: false,
            ),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
              ),
              child: Text(
                arrived ? 'AT THE DOOR' : 'ON THE WAY',
                style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: SetuColors.inkLight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A round map pin with an optional soft halo while the trip is live.
class _Marker extends StatelessWidget {
  const _Marker({
    required this.icon,
    required this.color,
    required this.pulsing,
  });

  final IconData icon;
  final Color color;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final pin = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(icon, color: Colors.white, size: 19),
    );
    if (!pulsing) return pin;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: pin,
    );
  }
}

/// The dashed route curve between the two markers.
class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Soft map grid.
    final grid = Paint()
      ..color = SetuColors.borderLight.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Dashed route from the caregiver pin to the home pin.
    final path = Path()
      ..moveTo(58, 62)
      ..cubicTo(size.width * 0.42, 52, size.width * 0.55, size.height - 46,
          size.width - 58, size.height - 62);
    final stroke = Paint()
      ..color = SetuColors.accentLight.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;
    const dash = 9.0, gap = 7.0;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final next = d + dash;
        canvas.drawPath(
            m.extractPath(d, next.clamp(0, m.length)), stroke);
        d = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SetuIconChip(
              icon: trip.status == TripStatus.arrived
                  ? Icons.doorbell_outlined
                  : trip.status == TripStatus.completed
                      ? Icons.check_circle_outline
                      : Icons.directions_car_filled_outlined,
              color: color,
              size: 24,
            ),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Text(headline,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: SetuSpacing.sm),
          Text(sub,
              style: const TextStyle(
                  color: SetuColors.mutedLight, fontSize: 15, height: 1.35)),
        ],
      ],
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
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        children: [
          for (var i = 0; i < labels.length; i++)
            _Step(
              label: labels[i],
              done: i < index,
              active: i == index,
              isLast: i == labels.length - 1,
            ),
        ],
      ),
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
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: reached ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : active
                        ? const Center(
                            child: SizedBox(
                              width: 8,
                              height: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                              ),
                            ),
                          )
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        done ? SetuColors.verifiedLight : SetuColors.borderLight,
                  ),
                ),
            ],
          ),
          const SizedBox(width: SetuSpacing.md),
          Padding(
            padding: EdgeInsets.only(
                top: 2, bottom: isLast ? 0 : SetuSpacing.lg),
            child: Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: reached ? SetuColors.inkLight : SetuColors.mutedLight,
                )),
          ),
        ],
      ),
    );
  }
}
