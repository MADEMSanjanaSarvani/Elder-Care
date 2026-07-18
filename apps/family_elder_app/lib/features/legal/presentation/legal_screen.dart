import 'package:flutter/material.dart';
import 'package:setu_core/setu_core.dart';

/// A plain, readable legal document viewer (Privacy Policy / Terms). Kept as
/// an in-app screen so Play Store's "policy reachable inside the app"
/// requirement is met without opening a browser.
class LegalScreen extends StatelessWidget {
  const LegalScreen({
    required this.title,
    required this.body,
    this.updated,
    super.key,
  });

  final String title;
  final String body;
  final String? updated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (updated != null) ...[
            const SizedBox(height: 4),
            Text(updated!,
                style: const TextStyle(color: SetuColors.mutedLight)),
          ],
          const SizedBox(height: SetuSpacing.lg),
          // Simple, dependency-free rendering: ALL-CAPS lines become section
          // headers, everything else is body text.
          for (final line in body.trim().split('\n'))
            _line(context, line),
          const SizedBox(height: SetuSpacing.xl),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return const SizedBox(height: SetuSpacing.sm);
    final isHeader = trimmed == trimmed.toUpperCase() &&
        RegExp(r'[A-Z]').hasMatch(trimmed) &&
        trimmed.length < 48;
    if (isHeader) {
      return Padding(
        padding: const EdgeInsets.only(top: SetuSpacing.md, bottom: 4),
        child: Text(trimmed,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: SetuColors.accentLight)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(trimmed, style: const TextStyle(height: 1.45)),
    );
  }
}
