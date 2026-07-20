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
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/icon/icon.png',
                          width: 68, height: 68),
                    ),
                  ),
                  const SizedBox(height: SetuSpacing.lg),
                  Text('Welcome to SETU',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'One last step — tell us who you are so we can set up the '
                    'right home for you.',
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
                    title: "I'm a family member",
                    subtitle: 'See and manage care for your parent or elder.',
                    busy: _busy,
                    onTap: () => _choose('family_member'),
                  ),
                  const SizedBox(height: SetuSpacing.sm),
                  _RoleCard(
                    icon: Icons.elderly,
                    color: SetuColors.peachLight,
                    title: "I'm the senior",
                    subtitle: 'A simple, large-text app made just for me.',
                    busy: _busy,
                    onTap: () => _choose('elder'),
                  ),
                  const SizedBox(height: SetuSpacing.sm),
                  _RoleCard(
                    icon: Icons.medical_services_outlined,
                    color: SetuColors.lavenderLight,
                    title: "I'm a caregiver",
                    subtitle: 'My visits, check-ins and earnings.',
                    busy: _busy,
                    onTap: () => _choose('caregiver'),
                  ),
                  const SizedBox(height: SetuSpacing.lg),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => ref
                            .read(supabaseClientProvider)
                            .auth
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
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(SetuSpacing.sm),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12.5, color: SetuColors.mutedLight)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: SetuColors.mutedLight),
          ],
        ),
      ),
    );
  }
}
