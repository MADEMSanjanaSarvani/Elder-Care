import 'package:flutter_test/flutter_test.dart';
import 'package:setu_core/setu_core.dart';

void main() {
  group('Booking.fromJson', () {
    test('parses status, dates, and an assigned caregiver', () {
      final booking = Booking.fromJson({
        'id': 'b-1',
        'elder_id': 'e-1',
        'service_id': 's-1',
        'caregiver_id': 'cg-1',
        'status': 'in_progress',
        'scheduled_at': '2026-07-16T09:30:00Z',
      });
      expect(booking.status, BookingStatus.inProgress);
      expect(booking.caregiverId, 'cg-1');
      expect(booking.scheduledAt, DateTime.utc(2026, 7, 16, 9, 30));
    });

    test('caregiver_id is null before a match', () {
      final booking = Booking.fromJson({
        'id': 'b-2',
        'elder_id': 'e-1',
        'service_id': 's-1',
        'caregiver_id': null,
        'status': 'requested',
        'scheduled_at': '2026-07-16T09:30:00Z',
      });
      expect(booking.status, BookingStatus.requested);
      expect(booking.caregiverId, isNull);
    });

    test('every BookingStatus round-trips through its wire value', () {
      for (final status in BookingStatus.values) {
        expect(BookingStatus.fromWire(status.wireValue), status,
            reason: status.name);
      }
    });
  });

  group('SetuService.fromJson', () {
    test('coerces an integer base_price to double and parses tier', () {
      final service = SetuService.fromJson({
        'id': 's-1',
        'code': 'companion',
        'name': 'Companion visit',
        'base_price': 500, // int from JSON
        'currency': 'INR',
        'requires_trust_tier': 'standard',
      });
      expect(service.basePrice, 500.0);
      expect(service.basePrice, isA<double>());
      expect(service.requiresTrustTier, TrustTier.standard);
    });
  });

  group('ElderProfile.fromJson', () {
    test('parses optional dob and defaults language to en', () {
      final elder = ElderProfile.fromJson({
        'id': 'e-1',
        'region_id': 'r-1',
        'auth_user_id': null,
        'display_name': 'Rao',
        'dob': null,
      });
      expect(elder.dob, isNull);
      expect(elder.authUserId, isNull);
      expect(elder.primaryLanguage, 'en');
    });

    test('parses a provided dob and language', () {
      final elder = ElderProfile.fromJson({
        'id': 'e-2',
        'region_id': 'r-1',
        'display_name': 'Lakshmi',
        'dob': '1948-03-12',
        'primary_language': 'te',
      });
      expect(elder.dob, DateTime(1948, 3, 12));
      expect(elder.primaryLanguage, 'te');
    });
  });

  group('FamilyLink.fromJson', () {
    test('parses status and optional relationship', () {
      final link = FamilyLink.fromJson({
        'id': 'fl-1',
        'elder_id': 'e-1',
        'family_user_id': 'f-1',
        'relationship': 'daughter',
        'status': 'active',
      });
      expect(link.status, FamilyLinkStatus.active);
      expect(link.relationship, 'daughter');
    });

    test('every FamilyLinkStatus round-trips', () {
      for (final status in FamilyLinkStatus.values) {
        expect(FamilyLinkStatus.fromWire(status.wireValue), status,
            reason: status.name);
      }
    });
  });

  group('Region.fromJson', () {
    test('parses the Visakhapatnam-style config', () {
      final region = Region.fromJson({
        'code': 'IN-VZG',
        'display_name': 'Visakhapatnam',
        'country_code': 'IN',
        'currency': 'INR',
        'tax_profile': {'gst_percent': 18},
        'payment_provider': 'razorpay',
        'bgv_provider': 'idfy',
        'compliance_profile': 'india_dpdp',
        'status': 'active',
      });
      expect(region.currency, 'INR');
      expect(region.taxProfile['gst_percent'], 18);
      expect(region.paymentProvider, 'razorpay');
    });
  });
}
