// Reduce-motion is an accessibility guarantee, not a nicety.
//
// The people who switch it on get motion sickness or vestibular symptoms from
// animation, and CareHive is a health app aimed at older people — which is
// exactly the population most likely to have it on. A regression here would be
// invisible to anyone testing with it off, so it is pinned.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_elder_app/core/motion.dart';

/// Renders a probe under a given MediaQuery and reports what Motion.of gave it.
Future<Duration> _durationUnder(
  WidgetTester tester, {
  required bool disableAnimations,
}) async {
  late Duration seen;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(
        builder: (context) {
          seen = Motion.of(context, Motion.normal);
          return const SizedBox();
        },
      ),
    ),
  );
  return seen;
}

void main() {
  group('Motion.of', () {
    testWidgets('collapses every duration to zero when reduce motion is on',
        (tester) async {
      expect(
        await _durationUnder(tester, disableAnimations: true),
        Duration.zero,
      );
    });

    testWidgets('passes the duration through when reduce motion is off',
        (tester) async {
      expect(
        await _durationUnder(tester, disableAnimations: false),
        Motion.normal,
      );
    });

    test('the timings stay short enough to be feedback, not choreography', () {
      // Somebody marking four doses in a row must not be made to wait on four
      // animations. If these ever grow past a blink, the interaction has
      // stopped being feedback and started being a performance.
      expect(Motion.fast.inMilliseconds, lessThanOrEqualTo(200));
      expect(Motion.normal.inMilliseconds, lessThanOrEqualTo(300));
      expect(Motion.slow.inMilliseconds, lessThanOrEqualTo(500));
    });
  });
}
