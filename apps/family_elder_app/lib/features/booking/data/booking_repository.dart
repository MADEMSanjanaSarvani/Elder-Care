import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingRepository {
  BookingRepository(this._client);

  final SupabaseClient _client;

  Future<List<SetuService>> fetchServices(String regionId) async {
    final rows = await _client
        .from('service_catalog')
        .select()
        .eq('region_id', regionId)
        .eq('active', true);
    return rows.map((row) => SetuService.fromJson(row)).toList();
  }

  Future<List<Booking>> fetchBookings(String elderId) async {
    final rows = await _client
        .from('bookings')
        .select()
        .eq('elder_id', elderId)
        .order('scheduled_at', ascending: false);
    return rows.map((row) => Booking.fromJson(row)).toList();
  }

  /// PRD Part 2 §12: goes through the `bookings-create` Edge Function, not
  /// a direct insert, so the required-trust-tier check happens server-side
  /// and can never be skipped by a client that "forgot." [caregiverId], when
  /// given, requests that specific caregiver (re-validated server-side); null
  /// means "match me the best available".
  Future<Booking> createBooking({
    required String elderId,
    required String serviceId,
    required DateTime scheduledAt,
    String? caregiverId,
  }) async {
    final response = await _client.functions.invoke(
      'bookings-create',
      body: {
        'elder_id': elderId,
        'service_id': serviceId,
        'scheduled_at': scheduledAt.toIso8601String(),
        if (caregiverId != null) 'caregiver_id': caregiverId,
      },
    );
    if (response.status != 201) {
      throw StateError('Booking failed: ${response.data}');
    }
    return Booking.fromJson(response.data as Map<String, dynamic>);
  }

  /// Creates a Razorpay hosted payment link to pay for a booked visit. Throws
  /// a FunctionException with status 503 when payments aren't configured.
  Future<Map<String, dynamic>> createBookingPaymentLink(
      {required String bookingId}) async {
    final res = await _client.functions
        .invoke('payments-booking-link', body: {'booking_id': bookingId});
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Withdraws a visit request that was never paid for.
  ///
  /// A booking row has to exist before a payment link can reference it, so
  /// it is created first and only becomes a real, dispatchable visit once the
  /// money arrives. If the family backs out at the payment step the request
  /// must not be left sitting in the queue looking live, or a caregiver could
  /// be assigned to a visit nobody paid for.
  ///
  /// Scoped to the pre-confirmation states, so it can never cancel a visit
  /// that is already confirmed, under way or finished.
  Future<void> cancelUnpaidBooking(String bookingId) async {
    await _client
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('id', bookingId)
        .inFilter('status', ['requested', 'matched']);
  }

  /// Verifies the visit payment with Razorpay and marks it captured. Returns
  /// true once paid.
  Future<bool> confirmBookingPayment(
      {required String linkId, required String bookingId}) async {
    final res = await _client.functions.invoke('payments-booking-confirm',
        body: {'link_id': linkId, 'booking_id': bookingId});
    return (res.data as Map)['paid'] == true;
  }

  /// The caregivers a family can choose from for a given service, curated
  /// server-side (`caregivers-for-service`): only active, verified caregivers
  /// in the elder's region whose trust tier meets the service, with the
  /// family-facing fields (name, role, trust tier, bio, photo, rating).
  Future<List<Map<String, dynamic>>> fetchCaregiversForService({
    required String elderId,
    required String serviceId,
    double? lat,
    double? lng,
  }) async {
    final response = await _client.functions.invoke(
      'caregivers-for-service',
      body: {
        'elder_id': elderId,
        'service_id': serviceId,
        if (lat != null && lng != null) 'lat': lat,
        if (lat != null && lng != null) 'lng': lng,
      },
    );
    final data = response.data as Map<String, dynamic>?;
    return ((data?['caregivers'] as List?) ?? []).cast<Map<String, dynamic>>();
  }
}
