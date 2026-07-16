import 'package:flutter_test/flutter_test.dart';
import 'package:setu_core/setu_core.dart';

void main() {
  group('ConsentCategory wire mapping', () {
    test('every enum value round-trips through its wire value', () {
      for (final category in ConsentCategory.values) {
        expect(ConsentCategory.fromWire(category.wireValue), category,
            reason: category.name);
      }
    });

    test('the wire values match the Postgres enum exactly', () {
      // If these drift from the DB enum, the client and server disagree
      // about what a grant means — pin them here.
      expect(ConsentCategory.locationLive.wireValue, 'location_live');
      expect(ConsentCategory.locationHistory.wireValue, 'location_history');
      expect(ConsentCategory.healthNotes.wireValue, 'health_notes');
      expect(ConsentCategory.medicationList.wireValue, 'medication_list');
      expect(ConsentCategory.visitHistory.wireValue, 'visit_history');
      expect(ConsentCategory.billing.wireValue, 'billing');
      expect(ConsentCategory.wellbeingCheckins.wireValue, 'wellbeing_checkins');
    });

    test('an unknown wire value throws rather than silently defaulting', () {
      expect(
        () => ConsentCategory.fromWire('not_a_category'),
        throwsArgumentError,
      );
    });
  });

  group('ConsentGrant.fromJson', () {
    test('parses a full active grant', () {
      final grant = ConsentGrant.fromJson({
        'elder_id': 'elder-1',
        'family_user_id': 'family-1',
        'category': 'health_notes',
        'granted': true,
        'granted_via': 'elder_app',
        'granted_at': '2026-01-01T00:00:00Z',
        'revoked_at': null,
      });
      expect(grant.category, ConsentCategory.healthNotes);
      expect(grant.grantedVia, ConsentGrantSource.elderApp);
      expect(grant.isActive, isTrue);
      expect(grant.revokedAt, isNull);
    });

    test('a revoked grant is not active', () {
      final grant = ConsentGrant.fromJson({
        'elder_id': 'elder-1',
        'family_user_id': 'family-1',
        'category': 'billing',
        'granted': true,
        'granted_via': 'documented_guardian_process',
        'granted_at': '2026-01-01T00:00:00Z',
        'revoked_at': '2026-02-01T00:00:00Z',
      });
      expect(grant.grantedVia, ConsentGrantSource.documentedGuardianProcess);
      expect(grant.isActive, isFalse);
    });

    test('granted = false is not active', () {
      final grant = ConsentGrant.fromJson({
        'elder_id': 'elder-1',
        'family_user_id': 'family-1',
        'category': 'billing',
        'granted': false,
        'granted_via': 'elder_app',
        'granted_at': null,
        'revoked_at': null,
      });
      expect(grant.isActive, isFalse);
    });
  });
}
