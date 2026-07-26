import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';

/// Shown once, right after a brand-new account is created, whenever the
/// signed-in user has no `profiles` row yet. This is a router-level gate
/// (see [HomeRouterScreen]) rather than a step inside the login screen: the
/// moment sign-up creates a session the router redirects away from /login,
/// so role selection has to live on the far side of that redirect to be
/// reliable. Picking a role writes the profile and drops the user into the
/// right home.
///
/// Matches the Stitch "role_selection" design: big rounded role cards with
/// a first-person description and an arrow-led action label, plus the
/// "Because Distance Should Never Mean Less Care." line already used on
/// the onboarding splash (the same real copy, not a new tagline).
class ChooseRoleScreen extends ConsumerStatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  ConsumerState<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends ConsumerState<ChooseRoleScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _choose(String role) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthRepository(ref.read(supabaseClientProvider))
          .ensureProfile(role: role, preferredLanguage: 'en');
      // Rebuild the home router so it now finds the fresh profile row.
      ref.invalidate(currentProfileProvider);
    } catch (err) {
      setState(() {
        _error = err.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text('SETU',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: SetuColors.accentLight,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                  const SizedBox(height: SetuSpacing.md),
                  Text('Welcome to SETU',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Please select the role that best describes your primary '
                    'use of the platform.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: SetuColors.mutedLight, height: 1.5),
                  ),
                  const SizedBox(height: SetuSpacing.xl),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(SetuSpacing.md),
                      decoration: BoxDecoration(
                        color: SetuColors.sosLight.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: SetuColors.sosLight.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: SetuColors.sosLight, size: 18),
                          const SizedBox(width: SetuSpacing.sm),
                          Expanded(
                              child: Text('Could not save that — $_error',
                                  style: const TextStyle(
                                      color: SetuColors.sosLight))),
                        ],
                      ),
                    ),
                    const SizedBox(height: SetuSpacing.md),
                  ],
                  _RoleCard(
                    icon: Icons.family_restroom,
                    color: SetuColors.accentLight,
                    title: 'Family Member',
                    subtitle:
                        'I want to stay connected and monitor the well-being '
                        'of my loved ones from anywhere.',
                    actionLabel: 'Select Profile',
                    busy: _busy,
                    onTap: () => _choose('family_member'),
                  ),
                  const SizedBox(height: SetuSpacing.md),
                  _RoleCard(
                    icon: Icons.elderly,
                    color: SetuColors.peachLight,
                    title: 'Elderly User',
                    subtitle:
                        'I need a simple, accessible way to manage my health '
                        'and reach out for assistance if needed.',
                    actionLabel: 'Get Started',
                    busy: _busy,
                    onTap: () => _choose('elder'),
                  ),
                  const SizedBox(height: SetuSpacing.md),
                  _RoleCard(
                    icon: Icons.medical_services_outlined,
                    color: SetuColors.lavenderLight,
                    title: 'Verified Caregiver',
                    subtitle:
                        'I am a professional providing care and need tools to '
                        'efficiently coordinate and monitor tasks.',
                    actionLabel: 'Register Credentials',
                    busy: _busy,
                    onTap: () => _choose('caregiver'),
                  ),
                  const SizedBox(height: SetuSpacing.xl),
                  Text('MISSION STATEMENT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: SetuColors.mutedLight,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('"Because Distance Should Never Mean Less Care."',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: SetuColors.mutedLight,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: SetuSpacing.lg),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => AuthRepository(
                                ref.read(supabaseClientProvider))
                            .signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: SetuColors.paperRaisedLight,
          border: Border.all(color: SetuColors.borderLight),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: SetuSpacing.md),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: SetuSpacing.sm),
            Text(subtitle,
                style: const TextStyle(color: SetuColors.mutedLight, height: 1.4)),
            const SizedBox(height: SetuSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(actionLabel,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, color: color, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
