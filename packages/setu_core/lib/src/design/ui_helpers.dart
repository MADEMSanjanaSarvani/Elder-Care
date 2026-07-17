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

/// A calm, centered empty state: icon, title, and a short line of guidance.
class SetuEmptyState extends StatelessWidget {
  const SetuEmptyState({
    required this.icon,
    required this.title,
    this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
