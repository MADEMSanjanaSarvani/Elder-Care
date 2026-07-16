import 'package:flutter_test/flutter_test.dart';
import 'package:setu_core/setu_core.dart';

/// The ConsentGate decides whether a family member's UI even *shows* a
/// sensitive control. It is not the security boundary (RLS is), but if it
/// wrongly reports a revoked or ungranted category as viewable, the app
/// would surface a control that then dead-ends on a server 403 — a
/// confusing, trust-eroding bug. These tests pin the exact active/inactive
/// rules.
ConsentGrant _grant(
  ConsentCategory category, {
  bool granted = true,
  DateTime? revokedAt,
}) {
  return ConsentGrant(
    elderId: 'elder-1',
    familyUserId: 'family-1',
    category: category,
    granted: granted,
    grantedVia: ConsentGrantSource.elderApp,
    grantedAt: DateTime(2026, 1, 1),
    revokedAt: revokedAt,
  );
}

void main() {
  group('ConsentGate', () {
    test('an active grant makes its category viewable', () {
      final gate = ConsentGate([_grant(ConsentCategory.medicationList)]);
      expect(gate.canView(ConsentCategory.medicationList), isTrue);
    });

    test('a category with no grant is not viewable', () {
      final gate = ConsentGate([_grant(ConsentCategory.medicationList)]);
      expect(gate.canView(ConsentCategory.healthNotes), isFalse);
    });

    test('granted = false is not viewable', () {
      final gate = ConsentGate([
        _grant(ConsentCategory.healthNotes, granted: false),
      ]);
      expect(gate.canView(ConsentCategory.healthNotes), isFalse);
    });

    test('a revoked grant is not viewable even if granted is still true', () {
      final gate = ConsentGate([
        _grant(ConsentCategory.healthNotes, revokedAt: DateTime(2026, 2, 1)),
      ]);
      expect(gate.canView(ConsentCategory.healthNotes), isFalse);
    });

    test('an empty grant list hides every category', () {
      final gate = ConsentGate([]);
      for (final category in ConsentCategory.values) {
        expect(gate.canView(category), isFalse, reason: category.name);
      }
    });

    test('only the granted categories among many are viewable', () {
      final gate = ConsentGate([
        _grant(ConsentCategory.locationLive),
        _grant(ConsentCategory.billing, granted: false),
        _grant(ConsentCategory.visitHistory, revokedAt: DateTime(2026, 3, 1)),
        _grant(ConsentCategory.wellbeingCheckins),
      ]);
      expect(gate.canView(ConsentCategory.locationLive), isTrue);
      expect(gate.canView(ConsentCategory.wellbeingCheckins), isTrue);
      expect(gate.canView(ConsentCategory.billing), isFalse);
      expect(gate.canView(ConsentCategory.visitHistory), isFalse);
    });
  });
}
