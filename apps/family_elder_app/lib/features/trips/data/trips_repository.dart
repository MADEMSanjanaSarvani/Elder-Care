import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

/// A live caregiver trip for a booking. Mirrors the caregiver_trips row the
/// family watches over Realtime while a visit is on its way.
enum TripStatus { enRoute, arrived, completed, cancelled }

TripStatus _statusFrom(String? s) {
  switch (s) {
    case 'arrived':
      return TripStatus.arrived;
    case 'completed':
      return TripStatus.completed;
    case 'cancelled':
      return TripStatus.cancelled;
    default:
      return TripStatus.enRoute;
  }
}

String statusToDb(TripStatus s) => switch (s) {
      TripStatus.enRoute => 'en_route',
      TripStatus.arrived => 'arrived',
      TripStatus.completed => 'completed',
      TripStatus.cancelled => 'cancelled',
    };

class CaregiverTrip {
  const CaregiverTrip({
    required this.id,
    required this.bookingId,
    required this.status,
    this.currentLat,
    this.currentLng,
    this.destinationLat,
    this.destinationLng,
    this.etaMinutes,
    this.updatedAt,
  });

  final String id;
  final String bookingId;
  final TripStatus status;
  final double? currentLat;
  final double? currentLng;
  final double? destinationLat;
  final double? destinationLng;
  final int? etaMinutes;
  final DateTime? updatedAt;

  static double? _num(dynamic v) =>
      v == null ? null : (v as num).toDouble();

  factory CaregiverTrip.fromMap(Map<String, dynamic> m) => CaregiverTrip(
        id: m['id'] as String,
        bookingId: m['booking_id'] as String,
        status: _statusFrom(m['status'] as String?),
        currentLat: _num(m['current_lat']),
        currentLng: _num(m['current_lng']),
        destinationLat: _num(m['destination_lat']),
        destinationLng: _num(m['destination_lng']),
        etaMinutes: (m['eta_minutes'] as num?)?.toInt(),
        updatedAt: m['updated_at'] != null
            ? DateTime.tryParse(m['updated_at'] as String)?.toLocal()
            : null,
      );

  /// Straight-line distance to the destination in km, when both points known.
  double? get distanceKm {
    if (currentLat == null ||
        currentLng == null ||
        destinationLat == null ||
        destinationLng == null) {
      return null;
    }
    return _haversineKm(
        currentLat!, currentLng!, destinationLat!, destinationLng!);
  }
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double toRad(double d) => d * math.pi / 180.0;
  final s1 = math.sin(toRad(lat2 - lat1) / 2);
  final s2 = math.sin(toRad(lng2 - lng1) / 2);
  final h = s1 * s1 +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * s2 * s2;
  return 2 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
}

class TripsRepository {
  TripsRepository(this._client);
  final SupabaseClient _client;

  /// Live stream of the trip for a booking (empty until one exists).
  Stream<CaregiverTrip?> watch(String bookingId) {
    return _client
        .from('caregiver_trips')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId)
        .map((rows) =>
            rows.isEmpty ? null : CaregiverTrip.fromMap(rows.first));
  }

  /// Live stream of any active (en_route/arrived) trip for an elder — powers
  /// the family home "your caregiver is on the way" banner.
  Stream<CaregiverTrip?> watchActiveForElder(String elderId) {
    return _client
        .from('caregiver_trips')
        .stream(primaryKey: ['id'])
        .eq('elder_id', elderId)
        .map((rows) {
          for (final r in rows) {
            final t = CaregiverTrip.fromMap(r);
            if (t.status == TripStatus.enRoute ||
                t.status == TripStatus.arrived) {
              return t;
            }
          }
          return null;
        });
  }

  /// One-shot read (for non-realtime consumers).
  Future<CaregiverTrip?> fetch(String bookingId) async {
    final row = await _client
        .from('caregiver_trips')
        .select()
        .eq('booking_id', bookingId)
        .maybeSingle();
    return row == null ? null : CaregiverTrip.fromMap(row);
  }

  /// Caregiver: open the live trip for a booking ("I'm on my way").
  Future<void> start(String bookingId, {int? etaMinutes}) async {
    await _client.functions.invoke('caregiver-trip-start', body: {
      'booking_id': bookingId,
      if (etaMinutes != null) 'eta_minutes': etaMinutes,
    });
  }

  /// Caregiver: push a fresh location (and optional ETA) to the live row.
  Future<void> pushLocation(String bookingId,
      {required double lat, required double lng, int? etaMinutes}) async {
    await _client.from('caregiver_trips').update({
      'current_lat': lat,
      'current_lng': lng,
      if (etaMinutes != null) 'eta_minutes': etaMinutes,
    }).eq('booking_id', bookingId);
  }

  /// Caregiver: advance the trip's lifecycle state.
  Future<void> setStatus(String bookingId, TripStatus status) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('caregiver_trips').update({
      'status': statusToDb(status),
      if (status == TripStatus.arrived) 'arrived_at': now,
      if (status == TripStatus.completed) 'completed_at': now,
    }).eq('booking_id', bookingId);
  }
}
