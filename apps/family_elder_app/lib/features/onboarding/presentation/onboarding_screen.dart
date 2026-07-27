import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/illustrations.dart';

/// Key persisted in SharedPreferences once onboarding has been seen.
const onboardingSeenKey = 'onboarding_seen_v1';

/// Set true once onboarding is seen so it never shows again. Loaded at
/// startup (see main.dart) and read by the router redirect.
final onboardingSeenProvider = StateProvider<bool>((ref) => true);

class _Slide {
  const _Slide(this.icon, this.tint, this.title, this.body);
  final IconData icon;
  final Color tint;
  final String title;
  final String body;
}

// Copy + order matched to the Stitch "Splash & Onboarding" design.
const _slides = <_Slide>[
  _Slide(Icons.monitor_heart_outlined, SetuColors.accentLight,
      'Stay Present, even when you\'re away.',
      'Real-time health insights and emotional connection tools designed for modern caregiving families.'),
  _Slide(Icons.auto_awesome_outlined, SetuColors.lavenderLight,
      'Peace of mind, powered by empathy.',
      'Advanced AI that understands patterns, predicts needs, and ensures safety without being intrusive.'),
  _Slide(Icons.diversity_1_outlined, SetuColors.peachLight,
      'Your Care Circle, unified in one place.',
      'Coordinate with doctors, siblings, and caregivers seamlessly. Because care is a shared journey.'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _showSplash = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    // Brief branded splash, then reveal the carousel (matches the design's
    // "ESTABLISHING CONNECTION" intro).
    _splashTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    ref.read(onboardingSeenProvider.notifier).state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingSeenKey, true);
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_page >= _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SetuColors.paperLight,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: _showSplash ? _splash(context) : _carousel(context),
        ),
      ),
    );
  }

  // ---- Splash ----------------------------------------------------------
  Widget _splash(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('splash'),
      children: [
        const Spacer(flex: 3),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: SetuColors.accentLight,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: SetuColors.accentLight.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.badge_outlined, color: Colors.white, size: 44),
        ),
        const SizedBox(height: SetuSpacing.lg),
        Text('SETU',
            style: theme.textTheme.displaySmall?.copyWith(
                color: SetuColors.accentLight,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const SizedBox(height: SetuSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text('Because Distance Should Never Mean Less Care.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: SetuColors.mutedLight, height: 1.4)),
        ),
        const Spacer(flex: 3),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
              color: SetuColors.accentLight, shape: BoxShape.circle),
        ),
        const SizedBox(height: SetuSpacing.md),
        Text('ESTABLISHING CONNECTION',
            style: theme.textTheme.labelMedium?.copyWith(
                color: SetuColors.mutedLight,
                letterSpacing: 2,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: SetuSpacing.xl),
      ],
    );
  }

  // ---- Carousel --------------------------------------------------------
  Widget _carousel(BuildContext context) {
    final theme = Theme.of(context);
    final last = _page == _slides.length - 1;
    return Column(
      key: const ValueKey('carousel'),
      children: [
        // On the last slide Skip is gone, not blanked. This rendered
        // `Text('')` inside a live TextButton — an invisible control in the
        // top-right corner that still finished onboarding when somebody
        // tapped what looked like empty space. The SizedBox holds the same
        // height so the carousel doesn't jump on the final page.
        Align(
          alignment: Alignment.centerRight,
          child: last
              ? const SizedBox(height: 48)
              : TextButton(onPressed: _finish, child: const Text('Skip')),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _slides.length,
            itemBuilder: (context, i) {
              final s = _slides[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: SetuSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 176,
                      height: 176,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          s.tint.withValues(alpha: 0.22),
                          s.tint.withValues(alpha: 0.06),
                        ]),
                      ),
                      // The first slide leads with the family illustration —
                      // it's the promise of the whole app. The rest keep
                      // their icons so each slide stays visually distinct.
                      child: i == 0
                          ? Center(child: SetuArt.family(height: 150))
                          : Icon(s.icon, size: 80, color: s.tint),
                    ),
                    const SizedBox(height: SetuSpacing.xl),
                    Text(s.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: SetuSpacing.md),
                    Text(s.body,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: SetuColors.mutedLight, height: 1.5)),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 32 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page
                      ? SetuColors.accentLight
                      : SetuColors.accentLight.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _next,
              icon: Icon(last ? Icons.check : Icons.arrow_forward),
              label: Text(last ? 'Get started' : 'Next'),
            ),
          ),
        ),
      ],
    );
  }
}
