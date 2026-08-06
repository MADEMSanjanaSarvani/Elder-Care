// The palette, checked by arithmetic instead of by eye.
//
// Every colour pair in CareHive was once chosen by looking at it on a bright
// desktop monitor, and five of them turned out to fail WCAG — including white
// on the Taken button at 3.83:1, which is the single most-pressed control in
// the app, aimed at older eyes. Nobody noticed, because "does that look OK?"
// answered on a good screen in good light is not the same question as "can a
// 75-year-old read this in a kitchen at dusk".
//
// So the palette has a test. Change a colour and this tells you what it broke.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setu_core/setu_core.dart';

/// Relative luminance, per WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// WCAG contrast ratio, 1.0 (identical) to 21.0 (black on white).
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void expectContrast(Color fg, Color bg, double min, String what) {
  final r = contrast(fg, bg);
  expect(r, greaterThanOrEqualTo(min),
      reason: '$what is ${r.toStringAsFixed(2)}:1, needs $min:1');
}

void main() {
  const white = Color(0xFFFFFFFF);

  group('light mode', () {
    test('a card is distinguishable from the page behind it', () {
      // Was 1.05 — white cards on a near-white page, no visible edge at all.
      expectContrast(SetuColors.paperRaisedLight, SetuColors.paperLight, 1.25,
          'card vs page');
    });

    test('borders are visible on both surfaces', () {
      expectContrast(
          SetuColors.borderLight, SetuColors.paperRaisedLight, 1.6, 'border vs card');
      expectContrast(
          SetuColors.borderLight, SetuColors.paperLight, 1.35, 'border vs page');
    });

    test('body and muted text clear AA on both surfaces', () {
      expectContrast(SetuColors.inkLight, SetuColors.paperLight, 12, 'ink on page');
      expectContrast(SetuColors.mutedLight, SetuColors.paperLight, 4.5, 'muted on page');
      expectContrast(
          SetuColors.mutedLight, SetuColors.paperRaisedLight, 4.5, 'muted on card');
    });

    test('every accent is readable as text on the page', () {
      for (final (name, c) in <(String, Color)>[
        ('accent', SetuColors.accentLight),
        ('verified', SetuColors.verifiedLight),
        ('sos', SetuColors.sosLight),
        ('lavender', SetuColors.lavenderLight),
        ('peach', SetuColors.peachLight),
      ]) {
        expectContrast(c, SetuColors.paperLight, 4.5, '$name on page');
      }
    });

    test('white on every filled button clears AA', () {
      // The one that mattered: Taken is white on verifiedLight, and was 3.83.
      for (final (name, c) in <(String, Color)>[
        ('accent', SetuColors.accentLight),
        ('verified — the Taken button', SetuColors.verifiedLight),
        ('sos', SetuColors.sosLight),
        ('lavender', SetuColors.lavenderLight),
        ('peach', SetuColors.peachLight),
      ]) {
        expectContrast(white, c, 4.5, 'white on $name');
      }
    });

    test('the navigation pill carries its own content', () {
      expectContrast(SetuColors.onLavenderContainerLight,
          SetuColors.lavenderContainerLight, 4.5, 'nav pill text');
    });
  });

  group('dark mode', () {
    test('a card is distinguishable from the page behind it', () {
      expectContrast(SetuColors.paperRaisedDark, SetuColors.paperDark, 1.20,
          'card vs page');
    });

    test('text and accents clear AA on the card', () {
      expectContrast(SetuColors.inkDark, SetuColors.paperDark, 12, 'ink on page');
      for (final (name, c) in <(String, Color)>[
        ('muted', SetuColors.mutedDark),
        ('accent', SetuColors.accentDark),
        ('verified', SetuColors.verifiedDark),
        ('sos', SetuColors.sosDark),
        ('lavender', SetuColors.lavenderDark),
        ('peach', SetuColors.peachDark),
      ]) {
        expectContrast(c, SetuColors.paperRaisedDark, 4.5, '$name on card');
      }
    });

    test('the navigation pill carries its own content', () {
      expectContrast(SetuColors.onLavenderContainerDark,
          SetuColors.lavenderContainerDark, 4.5, 'nav pill text');
    });
  });

  group('the contrast maths itself', () {
    test('matches the WCAG reference values', () {
      expect(contrast(const Color(0xFF000000), white), closeTo(21.0, 0.01));
      expect(contrast(white, white), closeTo(1.0, 0.001));
      // #767676 on white is the canonical "exactly AA" grey.
      expect(contrast(const Color(0xFF767676), white), closeTo(4.54, 0.05));
    });
  });
}
