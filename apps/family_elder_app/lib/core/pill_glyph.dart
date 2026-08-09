/// Draws the tablet, so a card can be matched to the thing in your hand.
///
/// People with four long-term prescriptions do not identify them by name. They
/// identify them as "the small white one" and "the big yellow capsule" — and
/// that is also how they get them wrong. CareHive was showing a name and a
/// dosage string, neither of which helps somebody holding a strip.
///
/// Two rules this file exists to enforce:
///
/// **Nothing is ever guessed.** There is no database of what a given drug looks
/// like — the same generic ships in different colours from different
/// manufacturers — so a pill only shows the appearance somebody actually
/// entered. With nothing entered it draws a neutral outline, which says "not
/// recorded" rather than quietly inventing a white tablet.
///
/// **Colour is never the only signal.** Roughly one man in twelve has some form
/// of colour blindness, and red/green and blue/purple are the common confusions
/// — so shape carries information too, the swatches are drawn with an outline
/// rather than floating on the card, and the name is always right beside it.
/// The glyph is a fast second confirmation, not a replacement for reading.
library;

import 'package:flutter/material.dart';
import 'package:setu_core/setu_core.dart';

/// The fixed set of colours a medicine may be described with.
///
/// A closed vocabulary rather than a colour picker, so every swatch stays
/// inside the range that is actually legible — a free picker produces pale
/// yellow tablets on a cream card that nobody can see, and the point of this
/// feature is being seen.
enum PillColor {
  white('white', Color(0xFFFAFAF8), 'White'),
  yellow('yellow', Color(0xFFE8C33F), 'Yellow'),
  orange('orange', Color(0xFFE2802B), 'Orange'),
  red('red', Color(0xFFC4423A), 'Red'),
  pink('pink', Color(0xFFE59BB0), 'Pink'),
  purple('purple', Color(0xFF8C7BC4), 'Purple'),
  blue('blue', Color(0xFF4F86C6), 'Blue'),
  green('green', Color(0xFF63A46C), 'Green'),
  brown('brown', Color(0xFF9A6B4A), 'Brown');

  const PillColor(this.token, this.swatch, this.label);

  /// What goes in the database. Never a hex value — see the migration.
  final String token;
  final Color swatch;
  final String label;

  static PillColor? fromToken(String? t) {
    if (t == null) return null;
    for (final c in values) {
      if (c.token == t) return c;
    }
    return null;
  }
}

enum PillShape {
  round('round', 'Round'),
  oval('oval', 'Oval'),
  capsule('capsule', 'Capsule'),
  oblong('oblong', 'Oblong');

  const PillShape(this.token, this.label);

  final String token;
  final String label;

  static PillShape? fromToken(String? t) {
    if (t == null) return null;
    for (final s in values) {
      if (s.token == t) return s;
    }
    return null;
  }
}

/// A small drawing of one tablet.
///
/// [color] or [shape] may be null — that is the normal state for a medicine
/// nobody has described yet, and it draws as a dashed neutral outline.
class PillGlyph extends StatelessWidget {
  const PillGlyph({
    required this.color,
    required this.shape,
    this.size = 34,
    super.key,
  });

  final PillColor? color;
  final PillShape? shape;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = shape ?? PillShape.round;
    final described = color != null || shape != null;

    // Proportions per shape, so an oblong reads as an oblong at 34px.
    final (w, h) = switch (s) {
      PillShape.round => (size * 0.78, size * 0.78),
      PillShape.oval => (size * 0.96, size * 0.66),
      PillShape.capsule => (size * 1.06, size * 0.56),
      PillShape.oblong => (size * 1.0, size * 0.62),
    };

    final radius = switch (s) {
      PillShape.round => w / 2,
      PillShape.oval => h / 2,
      PillShape.capsule => h / 2,
      PillShape.oblong => h * 0.34,
    };

    return SizedBox(
      width: size * 1.1,
      height: size,
      child: Center(
        child: Semantics(
          label: _describe(),
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: color?.swatch ?? Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              // Always outlined. A white tablet on a white card is otherwise
              // invisible, and an undescribed one needs to look deliberately
              // empty rather than accidentally blank.
              border: Border.all(
                color: described
                    ? SetuColors.inkLight.withValues(alpha: 0.35)
                    : SetuColors.borderLight,
                width: described ? 1.2 : 1.4,
              ),
            ),
            // A capsule is two halves, and that is most of how you recognise
            // one at a glance.
            child: s == PillShape.capsule && color != null
                ? Row(
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(radius)),
                          ),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  )
                : null,
          ),
        ),
      ),
    );
  }

  /// Read aloud by screen readers, and the reason colour is never load-bearing
  /// on its own.
  String _describe() {
    if (color == null && shape == null) return 'Appearance not recorded';
    final parts = [
      if (color != null) color!.label.toLowerCase(),
      if (shape != null) shape!.label.toLowerCase(),
    ];
    return '${parts.join(' ')} tablet';
  }
}

/// Pick a colour and a shape, or neither.
///
/// "Not sure" is a first-class answer and stays selectable at all times.
/// Somebody adding a medicine from a repeat prescription slip may not have the
/// box in front of them, and forcing a guess would put a wrong picture next to
/// a real tablet — worse than no picture, because it would be trusted.
class PillAppearancePicker extends StatelessWidget {
  const PillAppearancePicker({
    required this.color,
    required this.shape,
    required this.onChanged,
    super.key,
  });

  final PillColor? color;
  final PillShape? shape;
  final void Function(PillColor? color, PillShape? shape) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('What does it look like?',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            PillGlyph(color: color, shape: shape),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Optional — it helps you tell one tablet from another.',
          style: TextStyle(color: SetuColors.mutedLight, fontSize: 12.5),
        ),
        const SizedBox(height: SetuSpacing.sm),
        Wrap(
          spacing: SetuSpacing.sm,
          runSpacing: SetuSpacing.sm,
          children: [
            for (final c in PillColor.values)
              _Swatch(
                color: c,
                selected: color == c,
                onTap: () => onChanged(color == c ? null : c, shape),
              ),
          ],
        ),
        const SizedBox(height: SetuSpacing.md),
        Wrap(
          spacing: SetuSpacing.sm,
          runSpacing: SetuSpacing.sm,
          children: [
            for (final s in PillShape.values)
              ChoiceChip(
                label: Text(s.label),
                selected: shape == s,
                onSelected: (_) => onChanged(color, shape == s ? null : s),
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(
      {required this.color, required this.selected, required this.onTap});

  final PillColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: color.label,
      button: true,
      child: Tooltip(
        message: color.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.swatch,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? SetuColors.accentLight
                    : SetuColors.inkLight.withValues(alpha: 0.25),
                width: selected ? 3 : 1.2,
              ),
            ),
            // A tick, not just a ring — selection must survive being viewed by
            // somebody who cannot distinguish the ring colour from the swatch.
            child: selected
                ? Icon(Icons.check,
                    size: 20,
                    color: color == PillColor.white ||
                            color == PillColor.yellow ||
                            color == PillColor.pink
                        ? SetuColors.inkLight
                        : Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
