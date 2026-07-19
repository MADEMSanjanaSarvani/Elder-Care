import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/preferences.dart';
import '../../../core/providers.dart';
import '../../legal/legal_content.dart';
import '../../legal/presentation/legal_screen.dart';

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
            Text('Settings',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Customize your experience and manage your care circle.',
                style: TextStyle(color: SetuColors.mutedLight)),
            const SizedBox(height: SetuSpacing.xl),
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
            const SizedBox(height: SetuSpacing.xl),
            Text('Account & privacy',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: SetuSpacing.sm),
            _NavTile(
              icon: Icons.shield_outlined,
              label: 'Privacy Policy',
              onTap: () => _openLegal(context,
                  title: 'Privacy Policy',
                  body: kPrivacyPolicy,
                  updated: kPrivacyPolicyUpdated),
            ),
            _NavTile(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => _openLegal(context,
                  title: 'Terms of Service', body: kTermsOfService),
            ),
            _NavTile(
              icon: Icons.download_outlined,
              label: 'Export my data',
              subtitle: 'Download a copy of your CareHive data',
              onTap: () => _exportData(context, ref),
            ),
            _NavTile(
              icon: Icons.delete_outline,
              label: 'Delete my account',
              subtitle: 'Request permanent deletion of your account',
              danger: true,
              onTap: () => _deleteAccount(context, ref),
            ),
            const SizedBox(height: SetuSpacing.md),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(supabaseClientProvider).auth.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: SetuSpacing.xl),
            const Center(
              child: Text('CareHive · Version 1.0',
                  style:
                      TextStyle(color: SetuColors.mutedLight, fontSize: 12.5)),
            ),
            const SizedBox(height: SetuSpacing.lg),
          ],
        ),
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }

  void _openLegal(BuildContext context,
      {required String title, required String body, String? updated}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LegalScreen(title: title, body: body, updated: updated),
    ));
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ref.read(supabaseClientProvider).functions.invoke(
            'me-data-export',
            method: HttpMethod.get,
          );
      final json = res.data == null ? '{}' : res.data.toString();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your data is ready'),
          content: const Text(
              'We\'ve prepared a copy of your CareHive data. Copy it to save '
              'or share it wherever you like.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close')),
            FilledButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: json));
                Navigator.of(context).pop();
                messenger.showSnackBar(const SnackBar(
                    content: Text('Data copied to clipboard.')));
              },
              child: const Text('Copy'),
            ),
          ],
        ),
      );
    } catch (err) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not export data: $err')));
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'This asks our team to permanently delete your account and '
            'personal data. Some records may be kept where the law requires '
            '(e.g. payment and safety records). We\'ll confirm by email.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep my account')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SetuColors.sosLight),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Request deletion'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(supabaseClientProvider)
          .functions
          .invoke('me-erasure-request', body: {'reason': 'in-app request'});
      messenger.showSnackBar(const SnackBar(
          content: Text('Deletion requested. We\'ll email you to confirm.')));
    } catch (err) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not submit request: $err')));
    }
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? SetuColors.sosLight : SetuColors.accentLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(SetuSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SetuColors.borderLight),
          ),
          child: Row(
            children: [
              SetuIconChip(icon: icon, color: color, size: 18),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: danger ? SetuColors.sosLight : null)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 12.5, color: SetuColors.mutedLight)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SetuColors.mutedLight),
            ],
          ),
        ),
      ),
    );
  }
}
