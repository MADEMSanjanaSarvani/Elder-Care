/// What somebody sees the first time they open CareHive for themselves.
///
/// It replaces a dead end. An elder who installed the app alone used to land on
/// "Setting up your profile — ask your family to add you, then sign in again",
/// with nothing to tap and nothing to read. It was not a slow setup; it was
/// impossible: nothing in the entire system ever set `elder_profiles
/// .auth_user_id`, which is the column the app reads to find "the person that
/// is me". Waiting, reinstalling and signing in again would all have failed
/// identically and given no clue why.
///
/// That is the exact opposite of what CareHive promises. The whole reason this
/// app can exist is that it needs no second person — so the one screen that
/// demanded one had to go.
///
/// It does two jobs. It sets the person up in a single tap, and while they are
/// there it says plainly what the app will do for them, because the previous
/// screen explained nothing and a blank page teaches nobody why they should
/// bother adding their medicines.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../auth/data/auth_repository.dart';

class ElderSetupScreen extends ConsumerStatefulWidget {
  const ElderSetupScreen({super.key});

  @override
  ConsumerState<ElderSetupScreen> createState() => _ElderSetupScreenState();
}

class _ElderSetupScreenState extends ConsumerState<ElderSetupScreen> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      // `self: true` is the whole fix — it makes the new row belong to this
      // account instead of being a person somebody else looks after.
      await client.functions.invoke('family-add-elder', body: {
        'display_name': name,
        'self': true,
        'primary_language': 'en',
      });
      ref.invalidate(myElderProfilesProvider);
      // No navigation. The shell rebuilds on the provider and shows Today,
      // which is where they wanted to be.
    } catch (err) {
      if (mounted) {
        setState(() => _error = 'Could not set that up — $err');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.scaledForElderMode();

    // Their name from sign-up, so the field is usually already right and this
    // is a one-tap screen. Done in build rather than initState because the
    // profile arrives asynchronously.
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final signUpName = (profile?['display_name'] as String?)?.trim();
    if (!_prefilled && signUpName != null && signUpName.isNotEmpty) {
      _prefilled = true;
      _name.text = signUpName;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            SetuSpacing.lg, SetuSpacing.lg, SetuSpacing.lg, SetuSpacing.xl),
        children: [
          Text('Welcome to CareHive.',
              style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: SetuSpacing.xs),
          Text(
            'It keeps track of your medicines, so you never have to remember '
            'whether you took them.',
            style: t.titleMedium?.copyWith(color: SetuColors.mutedLight),
          ),
          const SizedBox(height: SetuSpacing.xl),

          const _Point(
            icon: Icons.alarm_on_outlined,
            title: 'Your phone will remind you',
            body: 'At every dose time, on the minute — even with no internet. '
                'Tap Taken on the reminder itself and it is recorded.',
          ),
          const _Point(
            icon: Icons.fact_check_outlined,
            title: 'It remembers what you took',
            body: 'So when a doctor asks how the last month went, you can '
                'show them instead of trying to recall it.',
          ),
          const _Point(
            icon: Icons.badge_outlined,
            title: 'It can speak for you',
            body: 'Your medicines, allergies and blood group on one screen, '
                'for a doctor — or a paramedic, if you cannot answer.',
          ),
          const _Point(
            icon: Icons.diversity_1_outlined,
            title: 'Your family can help, if you want',
            body: 'You can invite them later, and choose exactly what each '
                'person is allowed to see. Nobody sees anything until you say '
                'so.',
          ),

          const SizedBox(height: SetuSpacing.lg),
          Text('What should we call you?',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            style: t.titleMedium,
            decoration: const InputDecoration(
              hintText: 'Your name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: SetuSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    color: SetuColors.sosLight, size: 20),
                const SizedBox(width: SetuSpacing.sm),
                Expanded(
                  child: Text(_error!,
                      style: t.bodyMedium
                          ?.copyWith(color: SetuColors.sosLight)),
                ),
              ],
            ),
          ],
          const SizedBox(height: SetuSpacing.lg),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60)),
            onPressed: _busy ? null : _start,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text('Get started',
                    style: t.titleLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: SetuSpacing.md),
          Text(
            'CareHive is free. Nothing to pay, and nothing is sold.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: SetuColors.mutedLight),
          ),
          const SizedBox(height: SetuSpacing.lg),
          // The only way out for somebody who picked the wrong role at sign-up
          // and would otherwise be stuck on this screen forever.
          Center(
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () =>
                      AuthRepository(ref.read(supabaseClientProvider)).signOut(),
              child: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.scaledForElderMode();
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: SetuColors.accentLight.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: SetuColors.accentLight, size: 24),
          ),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body,
                    style: t.bodyLarge
                        ?.copyWith(color: SetuColors.mutedLight, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
