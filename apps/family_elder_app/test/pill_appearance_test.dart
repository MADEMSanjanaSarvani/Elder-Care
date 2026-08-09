// The Dart tokens and the database CHECK constraint have to agree exactly.
//
// `pill_color` and `pill_shape` are constrained columns. If somebody adds
// PillColor.grey to the enum and forgets the migration, nothing fails at
// compile time, nothing fails in any other test, and the swatch appears in the
// picker looking perfectly fine — then every attempt to save that medicine is
// rejected by Postgres. The person adding a medicine sees "Could not add
// medication: new row violates check constraint" and has no idea why.
//
// So this test reads the actual migration and compares. It is the only place
// the two halves of that contract are checked against each other.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:family_elder_app/core/pill_glyph.dart';

/// Pulls the allowed values out of `check (col in ('a','b',...))`.
Set<String> _allowedInMigration(String sql, String column) {
  final match = RegExp(
    '$column\\s+text\\s*\\n?\\s*check\\s*\\(\\s*$column\\s+in\\s*\\(([^)]*)\\)',
    caseSensitive: false,
  ).firstMatch(sql);
  if (match == null) {
    fail('No CHECK constraint found for $column in migration 0043');
  }
  return RegExp("'([^']+)'")
      .allMatches(match.group(1)!)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  final sql =
      File('../../supabase/migrations/0043_medicine_appearance.sql').readAsStringSync();

  group('appearance tokens match the database constraint', () {
    test('every colour the picker offers is one Postgres will accept', () {
      final allowed = _allowedInMigration(sql, 'pill_color');
      final offered = PillColor.values.map((c) => c.token).toSet();
      expect(offered, equals(allowed),
          reason: 'PillColor and migration 0043 have diverged — a medicine '
              'saved with a token the CHECK rejects fails at insert time');
    });

    test('every shape the picker offers is one Postgres will accept', () {
      final allowed = _allowedInMigration(sql, 'pill_shape');
      final offered = PillShape.values.map((s) => s.token).toSet();
      expect(offered, equals(allowed),
          reason: 'PillShape and migration 0043 have diverged');
    });
  });

  group('token round-tripping', () {
    test('every token parses back to the value it came from', () {
      for (final c in PillColor.values) {
        expect(PillColor.fromToken(c.token), c);
      }
      for (final s in PillShape.values) {
        expect(PillShape.fromToken(s.token), s);
      }
    });

    test('null and unknown tokens read as "not recorded", never as a default',
        () {
      // A medicine added before this feature existed has null in both columns,
      // and must draw as undescribed rather than silently becoming a white
      // round tablet — which would be the app inventing what a drug looks like.
      expect(PillColor.fromToken(null), isNull);
      expect(PillShape.fromToken(null), isNull);
      expect(PillColor.fromToken('chartreuse'), isNull);
      expect(PillShape.fromToken('rhombus'), isNull);
    });
  });
}
