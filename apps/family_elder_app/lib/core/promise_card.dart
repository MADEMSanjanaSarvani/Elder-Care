/// A short, coloured "here is what this app does for you" card.
///
/// Shared by the two welcome screens — the elder's first-run setup and the
/// family's empty dashboard — so the first thing both roles read looks like one
/// app rather than two.
///
/// The shape is deliberate. Both screens started as stacked paragraphs, and at
/// elder text scale a single paragraph filled half the phone: the heading
/// clipped under the app bar, the button was three screens down, and the whole
/// thing read as a document rather than a welcome. So each card gets one bold
/// line that carries the promise on its own, and one plain line underneath for
/// whoever reads further. Anything that will not fit in one line belongs in the
/// app, not on the welcome screen.
library;

import 'package:flutter/material.dart';
import 'package:setu_core/setu_core.dart';

import 'illustrations.dart';

class PromiseCard extends StatelessWidget {
  const PromiseCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
    this.elderScale = true,
    super.key,
  });

  final IconData icon;
  final Color tint;

  /// The promise, on its own. Assume this is the only line that gets read.
  final String title;

  /// One line for whoever reads further.
  final String body;

  /// Elder mode's larger type. Off on the family dashboard, which uses the
  /// normal scale.
  final bool elderScale;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme;
    final t = elderScale ? base.scaledForElderMode() : base;

    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.md),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text(body,
                      style: t.bodyMedium?.copyWith(
                          color: SetuColors.mutedLight, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The warm illustration band both welcome screens open with.
///
/// The art is a fixed height on purpose. An illustration that grew with the
/// text scale would push the actual content off the bottom of the phone for
/// exactly the people who need the larger text.
class WelcomeHero extends StatelessWidget {
  const WelcomeHero({this.height = 132, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: SetuSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SetuColors.peachLight.withValues(alpha: 0.22),
            SetuColors.accentLight.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Center(child: SetuArt.family(height: height)),
    );
  }
}
