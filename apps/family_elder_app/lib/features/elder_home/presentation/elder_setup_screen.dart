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
/// ## Why it is laid out like this
///
/// The first version was four stacked paragraphs. At elder text scale (up to
/// 1.5x) a single one of them filled half the phone, the heading was clipped
/// under the app bar, and the Get started button was three screens down —
/// which on a welcome screen means most people never reach it.
///
/// So: the button is **pinned** in a footer outside the scroll view, and can
/// never be scrolled away from at any text size. The four promises are short
/// coloured cards — one bold line and one plain line each — rather than
/// paragraphs, because somebody deciding whether to bother with an app reads
/// the bold line and nothing else. And there is a picture, because a wall of
/// text is what this screen looked like and it read as a form to fill in
/// rather than a welcome.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/promise_card.dart';
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
  void initState() {
    super.initState();
    // Covers the usual case: the profile is already cached by the time this
    // screen is built, so there is nothing to wait for.
    _prefillFrom(ref.read(currentProfileProvider).asData?.value);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Puts their sign-up name in the field, so this is a one-tap screen.
  ///
  /// Only into an empty field, and only once. On a slow connection somebody can
  /// start typing before the profile lands, and having their own name yanked
  /// out from under them mid-word is worse than not prefilling at all.
  void _prefillFrom(Map<String, dynamic>? profile) {
    if (_prefilled) return;
    final name = (profile?['display_name'] as String?)?.trim();
    if (name == null || name.isEmpty || _name.text.isNotEmpty) return;
    _prefilled = true;
    _name.text = name;
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

    // Catches the profile arriving after first paint, which is the whole
    // reason this is asynchronous at all.
    //
    // ref.listen and not ref.watch: assigning to a TextEditingController
    // notifies its listeners, and the TextField below is already mounted and
    // listening by the time a late profile lands. Doing that inside build()
    // makes the field call setState() during the build phase, which throws
    // "setState() or markNeedsBuild() called during build" — on the very
    // first screen a new user sees, in exactly the slow-connection case the
    // asynchrony exists for. Riverpod runs listeners after the frame, so this
    // is the safe place for a side effect.
    ref.listen(currentProfileProvider, (_, next) {
      _prefillFrom(next.asData?.value);
    });

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                SetuSpacing.lg, 0, SetuSpacing.lg, SetuSpacing.lg),
            children: [
              const WelcomeHero(),
              const SizedBox(height: SetuSpacing.md),
              Text('Welcome to CareHive',
                  style:
                      t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'So you never have to remember whether you took your '
                'medicines.',
                style: t.titleMedium?.copyWith(color: SetuColors.mutedLight),
              ),
              const SizedBox(height: SetuSpacing.lg),

              // One bold line each. Somebody deciding whether to bother with
              // an app reads the bold line and skips the rest, so the bold
              // line has to carry the promise on its own.
              const PromiseCard(
                icon: Icons.alarm_on_rounded,
                tint: SetuColors.accentLight,
                title: 'Your phone reminds you',
                body: 'On time, every dose — even with no internet.',
              ),
              const PromiseCard(
                icon: Icons.fact_check_rounded,
                tint: SetuColors.verifiedLight,
                title: 'It remembers for you',
                body: 'Show your doctor instead of trying to recall.',
              ),
              const PromiseCard(
                icon: Icons.badge_rounded,
                tint: SetuColors.peachLight,
                title: 'It can speak for you',
                body: 'Medicines, allergies and blood group, on one screen.',
              ),
              const PromiseCard(
                icon: Icons.diversity_1_rounded,
                tint: SetuColors.lavenderLight,
                title: 'Family only if you want',
                body: 'You invite them, and you choose what they see.',
              ),

              const SizedBox(height: SetuSpacing.lg),
              Text('What should we call you?',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: SetuSpacing.sm),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                style: t.titleMedium,
                onSubmitted: (_) => _busy ? null : _start(),
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
                          style:
                              t.bodyMedium?.copyWith(color: SetuColors.sosLight)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: SetuSpacing.md),
              // The only way out for somebody who picked the wrong role at
              // sign-up and would otherwise be stuck on this screen forever.
              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => AuthRepository(ref.read(supabaseClientProvider))
                          .signOut(),
                  child: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),

        // Pinned. Outside the ListView on purpose: at 1.5x text the cards above
        // are taller than the phone, and a Get started button that has to be
        // scrolled to is a button most people never find.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(SetuSpacing.lg, SetuSpacing.md,
              SetuSpacing.lg, SetuSpacing.md),
          decoration: const BoxDecoration(
            color: SetuColors.paperRaisedLight,
            border: Border(top: BorderSide(color: SetuColors.borderLight)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 6),
              Text('Free. Nothing to pay, and nothing is sold.',
                  style: t.bodySmall?.copyWith(color: SetuColors.mutedLight)),
            ],
          ),
        ),
      ],
    );
  }
}
