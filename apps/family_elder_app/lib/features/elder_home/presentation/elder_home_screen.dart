import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../medications/presentation/today_screen.dart';

// Local colour tokens for the greeting card's gradient — not promoted to
// SetuColors because nothing else uses them.
const _heroFrom = Color(0xFFFFDBC9); // primary-fixed
const _heroTo = Color(0xFFFF9F66); // primary-container
const _heroText = Color(0xFF773401); // on-primary-container

/// The elder's whole app on one screen: a warm greeting, today's doses with
/// their Taken buttons, and a large SOS bar pinned to the bottom — reachable
/// without reading, scrolling or choosing anything.
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
            // The home screen *is* today's doses.
            //
            // It used to be three tiles you had to choose between — Talk to AI,
            // Take Medicines, Daily Wellness — which meant the one thing this
            // app is for was one tap away behind a menu, and the tile above it
            // opened a chatbot that could not answer anything. The list of what
            // is due, with the buttons on it, is the screen now. Nothing to
            // pick, nothing to open.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      SetuSpacing.lg, SetuSpacing.lg, SetuSpacing.lg, 0),
                  child: _HeroGreeting(
                    greeting: greeting,
                    name: first,
                    t: t,
                    onMedicalId: () =>
                        context.push('/elder/${elder.id}/medical-id'),
                  ),
                ),
                // 140 clears the pinned SOS bar below.
                Expanded(
                  child: TodayScreen(
                    elderId: elder.id,
                    showAppBar: false,
                    bottomPadding: 140,
                  ),
                ),
              ],
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

/// Gradient hero card with the elder's name, and the one shortcut that has to
/// be reachable without reading anything: the medical ID a paramedic opens.
class _HeroGreeting extends StatelessWidget {
  const _HeroGreeting({
    required this.greeting,
    required this.name,
    required this.t,
    required this.onMedicalId,
  });

  final String greeting;
  final String name;
  final TextTheme t;
  final VoidCallback onMedicalId;

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
          const SizedBox(height: SetuSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onMedicalId,
              style: TextButton.styleFrom(
                foregroundColor: _heroText,
                backgroundColor: Colors.white.withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(
                    horizontal: SetuSpacing.md, vertical: SetuSpacing.sm),
              ),
              icon: const Icon(Icons.badge_outlined),
              label: Text('My medical ID',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
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
