import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_build.dart';
import '../../../core/preferences.dart';
import '../../../core/providers.dart';
import '../../payments/presentation/payment_flow_screens.dart';
import '../../legal/legal_content.dart';
import '../../legal/presentation/legal_screen.dart';
import '../../auth/data/auth_repository.dart';

/// Accessibility + language settings (PRD Part 8, Batch 5, Modules 19 &
/// 20), restyled to match the Stitch "settings_dashboard" design: sectioned
/// cards (Account & Security, Care Plan, Accessibility, Notifications,
/// Help & Support) instead of one long list. Text scale is a small set of
/// presets, not a free slider — simpler choice architecture for low digital
/// literacy. Changes apply app-wide immediately via userPreferencesProvider.
///
/// The Stitch mock also shows a "Personal Information" editor and a
/// "Password & Authentication — last changed 3 months ago" row; SETU has
/// neither a profile editor nor an auth-change timestamp, so those are
/// replaced with the real signed-in name (from currentProfileProvider) and
/// omitted respectively, rather than showing fabricated details.
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
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final name = (profile?['display_name'] as String?)?.trim();
    final elders = ref.watch(myElderProfilesProvider).asData?.value ?? [];
    final elderId = elders.isNotEmpty ? elders.first.id : null;

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

            // Account & Security
            _SettingsCard(
              icon: Icons.verified_user_outlined,
              iconBg: SetuColors.accentLight,
              title: 'Account & Security',
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  label: (name != null && name.isNotEmpty) ? name : 'Your account',
                  subtitle: 'Signed in',
                ),
                _NavRow(
                  icon: Icons.lock_outline,
                  label: 'Change password',
                  onTap: () => _changePassword(context, ref),
                ),
                _NavRow(
                  icon: Icons.switch_account_outlined,
                  label: 'How you use SETU',
                  trailingText: _roleLabel(profile?['role'] as String?),
                  onTap: () => _changeRole(context, ref,
                      current: profile?['role'] as String?),
                ),
              ],
              footer: OutlinedButton.icon(
                onPressed: () =>
                    AuthRepository(ref.read(supabaseClientProvider)).signOut(),
                icon: const Icon(Icons.logout, color: SetuColors.sosLight),
                label: const Text('Sign out',
                    style: TextStyle(color: SetuColors.sosLight)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SetuColors.sosLight)),
              ),
            ),
            const SizedBox(height: SetuSpacing.md),

            // Care plan (standout secondary-colour card, matches "SETU Plus").
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SetuSpacing.lg),
              decoration: BoxDecoration(
                color: SetuColors.lavenderLight.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: SetuColors.lavenderLight.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                            color: SetuColors.lavenderLight, shape: BoxShape.circle),
                        child: const Icon(Icons.workspace_premium_outlined,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: SetuSpacing.md),
                      Text('Care Plans',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: SetuSpacing.sm),
                  const Text('Manage your family\'s subscription and billing.',
                      style: TextStyle(color: SetuColors.mutedLight)),
                  const SizedBox(height: SetuSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: SetuColors.lavenderLight),
                      onPressed: elderId == null
                          ? null
                          : () => context.push('/elder/$elderId/care-plans'),
                      child: const Text('View plans'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SetuSpacing.md),

            // Accessibility
            _SettingsCard(
              icon: Icons.accessibility_new_outlined,
              iconBg: SetuColors.peachLight,
              title: 'Accessibility',
              children: [
                const Text('Text size', style: TextStyle(fontWeight: FontWeight.w700)),
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
                const SizedBox(height: SetuSpacing.md),
                _ToggleRow(
                  icon: Icons.contrast,
                  label: 'High contrast',
                  subtitle: 'Stronger colours, easier to read',
                  value: prefs.highContrast,
                  onChanged: (v) => notifier.save(highContrast: v),
                ),
                _ToggleRow(
                  icon: Icons.grid_view_outlined,
                  label: 'Simple mode',
                  subtitle: 'Fewer, larger buttons on the home screen',
                  value: prefs.simpleMode,
                  onChanged: (v) => notifier.save(simpleMode: v),
                ),
                _NavRow(
                  icon: Icons.language_outlined,
                  label: 'App Language',
                  trailingText: _languages[prefs.languageCode] ?? 'English',
                  onTap: () => _showLanguageSheet(
                      context, prefs.languageCode, notifier),
                ),
              ],
            ),
            const SizedBox(height: SetuSpacing.md),

            // Notifications
            _SettingsCard(
              icon: Icons.notifications_active_outlined,
              iconBg: SetuColors.accentLight,
              title: 'Notifications',
              children: [
                _NavRow(
                  icon: Icons.tune,
                  label: 'Manage notification preferences',
                  onTap: () => context.push('/notifications/preferences'),
                ),
              ],
            ),
            const SizedBox(height: SetuSpacing.md),

            // Help & Support / legal.
            _SettingsCard(
              icon: Icons.contact_support_outlined,
              iconBg: SetuColors.lavenderLight,
              title: 'Help & Support',
              children: [
                _NavRow(
                  icon: Icons.shield_outlined,
                  label: 'Privacy Policy',
                  onTap: () => _openLegal(context,
                      title: 'Privacy Policy',
                      body: kPrivacyPolicy,
                      updated: kPrivacyPolicyUpdated),
                ),
                _NavRow(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () => _openLegal(context,
                      title: 'Terms of Service', body: kTermsOfService),
                ),
                _NavRow(
                  icon: Icons.currency_rupee,
                  label: 'Cancellation & Refund Policy',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CancellationPolicyScreen())),
                ),
                _NavRow(
                  icon: Icons.download_outlined,
                  label: 'Export my data',
                  onTap: () => _exportData(context, ref),
                ),
                _NavRow(
                  icon: Icons.delete_outline,
                  label: 'Delete my account',
                  danger: true,
                  onTap: () => _deleteAccount(context, ref),
                ),
              ],
              footer: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: SetuSpacing.md, vertical: SetuSpacing.sm),
                decoration: BoxDecoration(
                  color: SetuColors.paperLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SetuColors.borderLight),
                ),
                child: Center(
                  child: Text('SETU · $kAppBuildLabel',
                      style: const TextStyle(
                          color: SetuColors.mutedLight, fontSize: 12.5)),
                ),
              ),
            ),
            const SizedBox(height: SetuSpacing.lg),
          ],
        ),
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }

  /// Set a new password from inside the app.
  ///
  /// Supabase's updateUser needs only the current session, not the old
  /// password, so there is nothing to verify here — the session itself is the
  /// proof. Requiring the old password anyway would be theatre, and would
  /// lock out anyone who arrived through Google sign-in and has no password
  /// to type.
  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final pw = TextEditingController();
    final confirm = TextEditingController();
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pw,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: SetuSpacing.sm),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm new password'),
              ),
              if (error != null) ...[
                const SizedBox(height: SetuSpacing.sm),
                Text(error!,
                    style: const TextStyle(color: SetuColors.sosLight)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (pw.text.length < 8) {
                  setLocal(() => error = 'Use at least 8 characters.');
                  return;
                }
                if (pw.text != confirm.text) {
                  setLocal(() => error = 'The two passwords don\'t match.');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthRepository(ref.read(supabaseClientProvider))
          .updatePassword(pw.text);
      messenger.showSnackBar(
          const SnackBar(content: Text('Password updated.')));
    } catch (err) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not change the password: $err')));
    }
  }

  static String _roleLabel(String? role) => switch (role) {
        'elder' => 'Senior',
        'caregiver' => 'Caregiver',
        _ => 'Family member',
      };

  /// Let someone change how they use SETU after sign-up.
  ///
  /// The role picker only ever appeared once, on a brand-new account, so
  /// anyone who chose wrongly — or who is both a daughter and a caregiver —
  /// was stuck for good with no way back short of a new account. Switching
  /// only rewrites `profiles.role`; elders, bookings and any caregiver
  /// application all survive, so this is reversible and needs no warning.
  Future<void> _changeRole(BuildContext context, WidgetRef ref,
      {required String? current}) async {
    const options = {
      'family_member': (
        'Family member',
        'Look after a parent or relative',
        Icons.diversity_1_outlined,
      ),
      'elder': (
        'Senior',
        'Use SETU for yourself, with larger text',
        Icons.elderly_outlined,
      ),
      'caregiver': (
        'Caregiver',
        'Provide care and accept visits',
        Icons.medical_services_outlined,
      ),
    };

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SetuColors.paperLight,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How do you use SETU?',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'You can change this whenever you like — nothing is lost.',
                style: TextStyle(color: SetuColors.mutedLight),
              ),
              const SizedBox(height: SetuSpacing.md),
              for (final e in options.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: SetuIconChip(
                      icon: e.value.$3,
                      color: e.key == current
                          ? SetuColors.accentLight
                          : SetuColors.mutedLight),
                  title: Text(e.value.$1,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(e.value.$2),
                  trailing: e.key == current
                      ? const Icon(Icons.check_circle,
                          color: SetuColors.accentLight)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(e.key),
                ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || picked == current || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthRepository(ref.read(supabaseClientProvider)).updateRole(picked);
      // The whole app shell is chosen from this value, so refresh it before
      // telling the user anything — otherwise they're looking at the old home.
      ref.invalidate(currentProfileProvider);
      await ref.read(currentProfileProvider.future);
      messenger.showSnackBar(SnackBar(
          content: Text('You are now using SETU as a '
              '${_roleLabel(picked).toLowerCase()}.')));
    } catch (err) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not change that: $err')));
    }
  }

  Future<void> _showLanguageSheet(BuildContext context, String current,
      UserPreferencesNotifier notifier) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: SetuColors.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: SetuSpacing.md),
                decoration: BoxDecoration(
                    color: SetuColors.borderLight,
                    borderRadius: BorderRadius.circular(999)),
              ),
            ),
            Text('App Language',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: SetuSpacing.sm),
            RadioGroup<String>(
              groupValue: current,
              onChanged: (v) {
                if (v != null) notifier.save(languageCode: v);
                Navigator.of(context).pop();
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
              'We\'ve prepared a copy of your SETU data. Copy it to save '
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

/// A rounded, bordered section card with an icon-badge header — the
/// building block behind every settings section (matches the Stitch
/// dashboard's card-per-section layout).
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.children,
    this.footer,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconBg, size: 20),
              ),
              const SizedBox(width: SetuSpacing.md),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
          ...children,
          if (footer != null) ...[
            const SizedBox(height: SetuSpacing.sm),
            Divider(color: SetuColors.borderLight),
            const SizedBox(height: SetuSpacing.sm),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.subtitle});
  final IconData icon;
  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SetuSpacing.xs),
      child: Row(
        children: [
          SetuIconChip(icon: icon, color: SetuColors.accentLight, size: 18),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 12.5, color: SetuColors.mutedLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: SetuColors.mutedLight),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailingText;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? SetuColors.sosLight : SetuColors.mutedLight;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SetuSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: danger ? SetuColors.sosLight : null)),
            ),
            if (trailingText != null)
              Text(trailingText!,
                  style: const TextStyle(
                      color: SetuColors.mutedLight, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: SetuColors.mutedLight),
          ],
        ),
      ),
    );
  }
}
