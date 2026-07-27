import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../family_home/presentation/family_home_screen.dart'
    show homeSummaryProvider;

// Local colour tokens lifted from the Stitch "elder_home_screen" design
// system (SETU's Material-3 palette) — not promoted to SetuColors because
// they're only used for this screen's bento tiles.
const _heroFrom = Color(0xFFFFDBC9); // primary-fixed
const _heroTo = Color(0xFFFF9F66); // primary-container
const _heroText = Color(0xFF773401); // on-primary-container
const _aiBg = Color(0xFFBEAEFD); // secondary-container
const _aiText = Color(0xFF4C3E84); // on-secondary-container
const _medIconBg = Color(0xFFFFDBC9); // primary-fixed

/// Elder home rebuilt to match the Stitch `elder_home_screen` design: a warm
/// gradient greeting, a stack of big bento-style action tiles (Talk to AI,
/// Take Medicines, Daily Wellness), and a massive SOS bar pinned to the
/// bottom of the tab — unmissable without needing a second of searching.
class ElderHomeScreen extends ConsumerWidget {
  const ElderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderProfiles = ref.watch(myElderProfilesProvider);
    final t = Theme.of(context).textTheme.scaledForElderMode();

    return elderProfiles.when(
      data: (elders) {
        if (elders.isEmpty) {
          return const SetuEmptyState(
            icon: Icons.elderly,
            title: 'Setting up your profile',
            message: 'Ask your family to add you, then sign in again.',
          );
        }
        final elder = elders.first;
        final first = elder.displayName.trim().split(' ').first;
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : 'Good evening';

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  SetuSpacing.lg, SetuSpacing.lg, SetuSpacing.lg, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero greeting (gradient card, Stitch's "Good morning, Dad.").
                  _HeroGreeting(greeting: greeting, name: first, t: t),
                  const SizedBox(height: SetuSpacing.md),

                  // Talk to AI Assistant (priority bento tile).
                  _BentoTile(
                    onTap: () => context.push('/elder/${elder.id}/assistant'),
                    color: _aiBg,
                    foreground: _aiText,
                    icon: Icons.smart_toy,
                    badgeIcon: Icons.mic,
                    title: 'Talk to AI Assistant',
                    subtitle: '"How are you feeling today?"',
                    t: t,
                  ),
                  const SizedBox(height: SetuSpacing.md),

                  // Take Medicines.
                  _BentoTile(
                    onTap: () => context.push('/elder/${elder.id}/medications'),
                    color: SetuColors.paperRaisedLight,
                    foreground: SetuColors.inkLight,
                    bordered: true,
                    icon: Icons.medical_services,
                    iconBg: _medIconBg,
                    iconColor: SetuColors.accentLight,
                    title: 'Take Medicines',
                    chipIcon: Icons.schedule,
                    // The one fact an elder opens this card for. It used to
                    // say "tap to see today's schedule", which made them do
                    // work to learn it. The Stitch design showed a fixed
                    // "Next dose: 10:30 AM"; this is the real next pending
                    // dose, and it says so honestly when there isn't one.
                    chipLabel: _nextDoseLabel(ref, elder.id),
                    t: t,
                  ),
                  const SizedBox(height: SetuSpacing.md),

                  // Daily Wellness.
                  _BentoTile(
                    onTap: () => context.push('/elder/${elder.id}/wellness'),
                    color: SetuColors.verifiedLight.withValues(alpha: 0.18),
                    foreground: SetuColors.inkLight,
                    icon: Icons.directions_walk,
                    iconBg: SetuColors.paperRaisedLight,
                    iconColor: SetuColors.verifiedLight,
                    title: 'Daily Wellness',
                    subtitle: 'A short walk each day keeps you strong, $first.',
                    t: t,
                  ),
                ],
              ),
            ),

            // SOS — pinned to the bottom of the tab, always reachable.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    SetuSpacing.lg, SetuSpacing.md, SetuSpacing.lg, SetuSpacing.lg),
                child: _SosButton(
                    onTap: () => context.push('/elder/${elder.id}/sos'), t: t),
              ),
            ),
          ],
        );
      },
      loading: () => const SetuLoading(),
      error: (err, stack) => const SetuErrorState(),
    );
  }
}

/// Gradient hero card with the elder's name and a warm, static tagline
/// (matches the Stitch "Good morning, Dad. It's a beautiful day." header).
class _HeroGreeting extends StatelessWidget {
  const _HeroGreeting({required this.greeting, required this.name, required this.t});

  final String greeting;
  final String name;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_heroFrom, _heroTo],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$greeting, $name.',
              style: t.headlineLarge
                  ?.copyWith(color: _heroText, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text("It's a beautiful day.",
              style: t.titleLarge?.copyWith(color: _heroText.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

/// A big, square-ish bento action tile — icon (or an icon + badge for the
/// AI tile), a headline, and either a plain subtitle or a small pill chip.
/// Matches the Stitch dashboard's large tappable action cards.
class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.onTap,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.title,
    required this.t,
    this.bordered = false,
    this.badgeIcon,
    this.iconBg,
    this.iconColor,
    this.subtitle,
    this.chipIcon,
    this.chipLabel,
  });

  final VoidCallback onTap;
  final Color color;
  final Color foreground;
  final bool bordered;
  final IconData icon;
  final IconData? badgeIcon;
  final Color? iconBg;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final IconData? chipIcon;
  final String? chipLabel;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(28),
      // The lift the designs give every bento tile. Material's own elevation
      // is used rather than a wrapping Container so the ink splash still
      // clips to the rounded corners.
      elevation: 3,
      shadowColor: SetuColors.peachLight.withValues(alpha: 0.45),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          height: 208,
          padding: const EdgeInsets.all(SetuSpacing.lg),
          decoration: bordered
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: SetuColors.borderLight, width: 2),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (iconBg != null)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                          color: iconBg, borderRadius: BorderRadius.circular(18)),
                      child: Icon(icon, color: iconColor ?? foreground, size: 30),
                    )
                  else
                    Icon(icon, color: foreground, size: 48),
                  if (badgeIcon != null)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(badgeIcon, color: foreground),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: t.headlineSmall
                          ?.copyWith(color: foreground, fontWeight: FontWeight.w800)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        style: t.bodyMedium
                            ?.copyWith(color: foreground.withValues(alpha: 0.85))),
                  ],
                  if (chipLabel != null) ...[
                    const SizedBox(height: SetuSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: SetuSpacing.sm, vertical: 6),
                      decoration: BoxDecoration(
                        color: SetuColors.accentLight.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (chipIcon != null) ...[
                            Icon(chipIcon, size: 18, color: SetuColors.accentLight),
                            const SizedBox(width: 6),
                          ],
                          Text(chipLabel!,
                              style: t.bodyMedium?.copyWith(
                                  color: SetuColors.accentLight,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The massive pulsing SOS bar pinned above the tab bar — the "unmissable"
/// emergency entry point (matches the Stitch design's fixed bottom button).
class _SosButton extends StatefulWidget {
  const _SosButton({required this.onTap, required this.t});
  final VoidCallback onTap;
  final TextTheme t;

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setuSyncBreathing(context, _controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.03)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Material(
        color: SetuColors.sosLight,
        borderRadius: BorderRadius.circular(40),
        elevation: 6,
        shadowColor: SetuColors.sosLight.withValues(alpha: 0.6),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: widget.onTap,
          child: Container(
            height: 88,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sos_rounded, color: Colors.white, size: 34),
                const SizedBox(width: SetuSpacing.md),
                Text('SOS',
                    style: widget.t.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// "Next dose: 10:30 AM", from the real schedule.
///
/// Falls back to plain statements rather than a guess. An overdue dose is
/// never described as "next" — calling a missed tablet the next one would
/// hide the fact that it was missed, which is the opposite of what an
/// adherence feature is for.
String _nextDoseLabel(WidgetRef ref, String elderId) {
  final summary = ref.watch(homeSummaryProvider(elderId)).asData?.value;
  if (summary == null) return "Today's schedule";
  if (summary.medsTotal == 0) return 'No medicines today';
  final at = summary.nextDoseAt;
  if (at == null) {
    return summary.medsTaken >= summary.medsTotal
        ? 'All done for today'
        : "Tap to see today's schedule";
  }
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  final period = at.hour < 12 ? 'AM' : 'PM';
  return 'Next dose: $hour:$minute $period';
}
