import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Shared presentation helpers so every screen speaks the same visual
/// language — a coloured icon chip, a friendly empty state, and human-
/// readable timestamps — without each feature re-inventing them.

/// A coloured circular icon badge used at the start of list rows and cards.
class SetuIconChip extends StatelessWidget {
  const SetuIconChip({
    required this.icon,
    this.color = SetuColors.accentLight,
    this.size = 20,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

/// A calm, centered empty state: artwork (or icon), title, and a short line
/// of guidance.
///
/// [artwork] takes precedence over [icon] when supplied — screens pass an
/// illustration from the app's asset bundle. The widget rather than an asset
/// path keeps this package free of asset declarations of its own.
class SetuEmptyState extends StatelessWidget {
  const SetuEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.artwork,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? artwork;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            artwork ??
                Icon(icon, size: 56, color: SetuColors.mutedLight),
            const SizedBox(height: SetuSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: SetuSpacing.xs),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SetuColors.mutedLight)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A calm branded loading state — a soft sage spinner centred with a little
/// breathing room, so every screen waits the same gentle way.
class SetuLoading extends StatelessWidget {
  const SetuLoading({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: SetuColors.accentLight),
          ),
          if (label != null) ...[
            const SizedBox(height: SetuSpacing.md),
            Text(label!, style: const TextStyle(color: SetuColors.mutedLight)),
          ],
        ],
      ),
    );
  }
}

/// A friendly error state — never a raw exception dumped on screen. Shows a
/// soft icon, a reassuring line, and an optional "Try again" button wired to
/// whatever refresh the caller provides.
class SetuErrorState extends StatelessWidget {
  const SetuErrorState({
    this.title = "That didn't load",
    this.message = 'Please check your connection and try again.',
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SetuIconChip(
                icon: Icons.cloud_off_outlined,
                color: SetuColors.peachLight,
                size: 34),
            const SizedBox(height: SetuSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SetuSpacing.xs),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SetuColors.mutedLight)),
            if (onRetry != null) ...[
              const SizedBox(height: SetuSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small status pill (coloured text on a soft tinted background).
class SetuStatusPill extends StatelessWidget {
  const SetuStatusPill({
    required this.label,
    this.color = SetuColors.accentLight,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SetuSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Human-readable date/time formatting shared across the app.
class SetuFormat {
  const SetuFormat._();

  static String _clock(DateTime dt) {
    final h = dt.hour == 0 || dt.hour == 12 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  /// e.g. "Today, 3:40 PM" · "Yesterday, 9:05 AM" · "12 Jan, 4:00 PM".
  static String friendlyTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final days = today.difference(that).inDays;
    final clock = _clock(dt);
    if (days == 0) return 'Today, $clock';
    if (days == 1) return 'Yesterday, $clock';
    if (days == -1) return 'Tomorrow, $clock';
    return '${dt.day} ${_month(dt.month)}, $clock';
  }

  /// e.g. "12 Jan 2026".
  static String friendlyDate(DateTime dt) =>
      '${dt.day} ${_month(dt.month)} ${dt.year}';

  static String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

/// Lifts a bottom navigation bar off the page the way every SETU design draws
/// it: white, rounded across the top, with a warm shadow falling upward.
///
/// NavigationBarThemeData has no shape, so this cannot come from the theme.
/// Wrapping is the only way to get the rounded top, and the upward shadow is
/// what separates the bar from the content instead of letting it blend into
/// the bottom of a scrolling list.
class SetuNavSurface extends StatelessWidget {
  const SetuNavSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? SetuColors.paperRaisedDark : SetuColors.paperRaisedLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : SetuColors.peachLight)
                .withValues(alpha: dark ? 0.4 : 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: child,
      ),
    );
  }
}

/// The soft out-of-focus colour blobs behind the SETU screens.
///
/// Two large circles bled off opposite corners at very low alpha. Cheap —
/// they are plain circles with a radial gradient, painted once, with no blur
/// filter and no animation, so they cost nothing per frame. That matters: the
/// designs achieve this with backdrop blur, which is one of the most expensive
/// things you can put on an entry-level Android GPU, and repeating it behind
/// every screen would be felt.
///
/// Put it at the bottom of a Stack, under the content.
class SetuAtmosphere extends StatelessWidget {
  const SetuAtmosphere({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _Blob(size: 340, color: SetuColors.peachLight),
          ),
          Positioned(
            bottom: -140,
            left: -110,
            child: _Blob(size: 300, color: SetuColors.lavenderLight),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // A radial gradient fading to nothing gives the same soft edge a blur
        // would, for none of the cost.
        gradient: RadialGradient(colors: [
          color.withValues(alpha: 0.14),
          color.withValues(alpha: 0.0),
        ]),
      ),
    );
  }
}
