import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/preferences.dart';

/// Accessibility + language settings (PRD Part 8, Batch 5, Modules 19 &
/// 20). Text scale is a small set of presets, not a free slider — simpler
/// choice architecture for low digital literacy. Changes apply app-wide
/// immediately via userPreferencesProvider.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _languages = {
    'en': 'English',
    'hi': 'हिन्दी (Hindi)',
    'te': 'తెలుగు (Telugu)',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(userPreferencesProvider);
    final notifier = ref.read(userPreferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: prefsAsync.when(
        data: (prefs) => ListView(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          children: [
            Text('Text size', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: SetuSpacing.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'default', label: Text('Default')),
                ButtonSegment(value: 'large', label: Text('Large')),
                ButtonSegment(value: 'extra_large', label: Text('Extra large')),
              ],
              selected: {prefs.textScale},
              onSelectionChanged: (s) => notifier.save(textScale: s.first),
            ),
            const SizedBox(height: SetuSpacing.xl),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('High contrast'),
              subtitle: const Text('Stronger colours, easier to read'),
              value: prefs.highContrast,
              onChanged: (v) => notifier.save(highContrast: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simple mode'),
              subtitle: const Text('Fewer, larger buttons on the home screen'),
              value: prefs.simpleMode,
              onChanged: (v) => notifier.save(simpleMode: v),
            ),
            const SizedBox(height: SetuSpacing.xl),
            Text('Language', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: SetuSpacing.sm),
            RadioGroup<String>(
              groupValue: prefs.languageCode,
              onChanged: (v) {
                if (v != null) notifier.save(languageCode: v);
              },
              child: Column(
                children: [
                  for (final entry in _languages.entries)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: entry.key,
                      title: Text(entry.value),
                    ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Something went wrong: $err')),
      ),
    );
  }
}
