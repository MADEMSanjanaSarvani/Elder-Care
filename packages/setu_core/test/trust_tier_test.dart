import 'package:flutter_test/flutter_test.dart';
import 'package:setu_core/setu_core.dart';

/// TrustTier.meets is the client-side "does this caregiver qualify for this
/// job" check (the server re-enforces it). It relies on enum *order*, so a
/// reordering of the enum would silently change who qualifies — these tests
/// pin both the ranking and the boundary behaviour.
void main() {
  group('TrustTier.meets', () {
    test('a tier meets its own requirement', () {
      for (final tier in TrustTier.values) {
        expect(tier.meets(tier), isTrue, reason: tier.name);
      }
    });

    test('a higher tier meets a lower requirement', () {
      expect(TrustTier.clinicalVerified.meets(TrustTier.standard), isTrue);
      expect(TrustTier.clinicalVerified.meets(TrustTier.probationary), isTrue);
      expect(TrustTier.standard.meets(TrustTier.probationary), isTrue);
    });

    test('a lower tier does NOT meet a higher requirement', () {
      expect(TrustTier.probationary.meets(TrustTier.standard), isFalse);
      expect(TrustTier.probationary.meets(TrustTier.clinicalVerified), isFalse);
      expect(TrustTier.standard.meets(TrustTier.clinicalVerified), isFalse);
    });

    test('the rank order is probationary < standard < clinical_verified', () {
      expect(TrustTier.probationary.index, lessThan(TrustTier.standard.index));
      expect(TrustTier.standard.index,
          lessThan(TrustTier.clinicalVerified.index));
    });
  });

  group('Caregiver / CaregiverType parsing', () {
    test('fromJson parses type and tier', () {
      final caregiver = Caregiver.fromJson({
        'id': 'cg-1',
        'caregiver_type': 'clinical',
        'trust_tier': 'clinical_verified',
        'display_name': 'Asha',
      });
      expect(caregiver.caregiverType, CaregiverType.clinical);
      expect(caregiver.trustTier, TrustTier.clinicalVerified);
      expect(caregiver.displayName, 'Asha');
    });

    test('display_name is optional', () {
      final caregiver = Caregiver.fromJson({
        'id': 'cg-2',
        'caregiver_type': 'non_clinical',
        'trust_tier': 'probationary',
      });
      expect(caregiver.caregiverType, CaregiverType.nonClinical);
      expect(caregiver.displayName, isNull);
    });
  });
}
