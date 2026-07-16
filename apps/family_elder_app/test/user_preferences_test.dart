import 'package:flutter_test/flutter_test.dart';
import 'package:family_elder_app/core/preferences.dart';

/// UserPreferences drives app-wide text scaling and simple/high-contrast
/// modes (Batch 5 accessibility). The textScaleFactor mapping is applied at
/// the MaterialApp root, so a wrong factor changes every screen at once —
/// worth pinning.
void main() {
  group('UserPreferences.textScaleFactor', () {
    test('default maps to 1.0', () {
      expect(const UserPreferences().textScaleFactor, 1.0);
    });

    test('large maps to 1.25', () {
      expect(
        const UserPreferences(textScale: 'large').textScaleFactor,
        1.25,
      );
    });

    test('extra_large maps to 1.5', () {
      expect(
        const UserPreferences(textScale: 'extra_large').textScaleFactor,
        1.5,
      );
    });

    test('an unrecognised value falls back to 1.0 (never zero/negative)', () {
      final factor =
          const UserPreferences(textScale: 'gigantic').textScaleFactor;
      expect(factor, 1.0);
      expect(factor, greaterThan(0));
    });
  });

  group('UserPreferences defaults and copyWith', () {
    test('defaults are the conservative, non-accessible baseline', () {
      const prefs = UserPreferences();
      expect(prefs.textScale, 'default');
      expect(prefs.highContrast, isFalse);
      expect(prefs.simpleMode, isFalse);
      expect(prefs.languageCode, 'en');
    });

    test('copyWith changes only the named field', () {
      const prefs = UserPreferences(
        textScale: 'large',
        highContrast: true,
        simpleMode: true,
        languageCode: 'te',
      );
      final next = prefs.copyWith(highContrast: false);
      expect(next.highContrast, isFalse);
      // everything else preserved
      expect(next.textScale, 'large');
      expect(next.simpleMode, isTrue);
      expect(next.languageCode, 'te');
    });

    test('copyWith with no arguments preserves all values', () {
      const prefs = UserPreferences(textScale: 'extra_large', simpleMode: true);
      final copy = prefs.copyWith();
      expect(copy.textScale, 'extra_large');
      expect(copy.simpleMode, isTrue);
    });
  });
}
