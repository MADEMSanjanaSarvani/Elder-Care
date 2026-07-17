import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const _slides = <_Slide>[
  _Slide(Icons.diversity_1_outlined, SetuColors.accentLight,
      'Stay connected with your loved ones',
      'See how your parents are doing every day — wherever you are.'),
  _Slide(Icons.volunteer_activism_outlined, SetuColors.peachLight,
      'Book trusted caregivers anytime',
      'Verified, background-checked helpers for visits, nursing and company.'),
  _Slide(Icons.monitor_heart_outlined, SetuColors.lavenderLight,
      'Monitor health & daily activities',
      'Medicines, appointments and gentle daily check-ins, all in one place.'),
  _Slide(Icons.sos_outlined, SetuColors.sosLight,
      'Emergency support whenever needed',
      'One tap calls for help and alerts your whole family at once.'),
  _Slide(Icons.auto_awesome_outlined, SetuColors.lavenderLight,
      'An AI companion for wellbeing',
      'Someone for them to talk to, plus warm weekly updates for you.'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
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
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(last ? '' : 'Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: SetuSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 168,
                          height: 168,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              s.tint.withValues(alpha: 0.22),
                              s.tint.withValues(alpha: 0.06),
                            ]),
                          ),
                          child: Icon(s.icon, size: 76, color: s.tint),
                        ),
                        const SizedBox(height: SetuSpacing.xl),
                        Text(s.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium),
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
            // dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
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
              child: FilledButton(
                onPressed: _next,
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
