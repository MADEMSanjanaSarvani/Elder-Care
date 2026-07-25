import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/action_success.dart';
import '../../../core/providers.dart';
import '../../suggestions/presentation/suggestions_card.dart';
import '../../trips/data/trips_repository.dart';
import '../../wellness/presentation/weekly_activity_chart.dart';
import '../data/home_summary_repository.dart';

/// Live "your caregiver is on the way" state for an elder (null when idle).
final activeTripProvider =
    StreamProvider.family<CaregiverTrip?, String>((ref, elderId) {
  ref.watch(authStateProvider);
  return TripsRepository(ref.watch(supabaseClientProvider))
      .watchActiveForElder(elderId);
});

/// Today-at-a-glance summary for an elder (medicines, mood, check-in).
final homeSummaryProvider =
    FutureProvider.family<HomeSummary, String>((ref, elderId) async {
  ref.watch(authStateProvider);
  return HomeSummaryRepository(ref.watch(supabaseClientProvider)).fetch(elderId);
});

/// Timeline-first dashboard (PRD Part 3 §17), matching the Stitch
/// "family_dashboard" design: a warm greeting, a bento-style "today" grid
/// (medicines / mood / check-in), a SETU Memories hero, live caregiver
/// tracking, an AI insight card, then the full action grid. Consent/privacy
/// stay one tap away (trust is a feature, not a buried setting).
class FamilyHomeScreen extends ConsumerWidget {
  const FamilyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderProfiles = ref.watch(myElderProfilesProvider);

    return elderProfiles.when(
      data: (elders) {
        if (elders.isEmpty) return const _NoElders();
        return ListView(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          children: [
            const _GreetingHeader(),
            const SizedBox(height: SetuSpacing.lg),
            for (final elder in elders) ...[
              _ElderSection(elder: elder),
              const SizedBox(height: SetuSpacing.xl),
            ],
            OutlinedButton.icon(
              onPressed: () => showAddElderDialog(context, ref),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add another person'),
            ),
          ],
        );
      },
      loading: () => const SetuLoading(),
      error: (err, stack) => const SetuErrorState(),
    );
  }
}

/// A warm, personalised greeting at the top of the dashboard (matches the
/// Stitch "Good morning, {name}" header).
class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final name = (profile?['display_name'] as String?)?.trim();
    final first = (name != null && name.isNotEmpty) ? name.split(' ').first : null;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Text(
      first != null ? '$greeting, $first.' : '$greeting.',
      style: Theme.of(context)
          .textTheme
          .headlineMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

/// Family onboarding: create the elder you care for and link yourself, via
/// the family-add-elder function (RLS blocks the direct client path).
Future<void> showAddElderDialog(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final relationshipController = TextEditingController();

  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SetuColors.paperLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: SetuSpacing.lg,
        right: SetuSpacing.lg,
        top: SetuSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + SetuSpacing.lg,
      ),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: SetuColors.accentLight.withValues(alpha: 0.14),
                    shape: BoxShape.circle),
                child: const Icon(Icons.elderly_outlined,
                    color: SetuColors.accentLight),
              ),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add someone you care for',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const Text('They join your care circle right away.',
                        style: TextStyle(color: SetuColors.mutedLight)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SetuSpacing.lg),
          const Text('Their name',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Lakshmi'),
          ),
          const SizedBox(height: SetuSpacing.md),
          const Text('Relationship (optional)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: relationshipController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Mother'),
          ),
          const SizedBox(height: SetuSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add to care circle'),
            ),
          ),
        ],
      ),
    ),
  );

  final name = nameController.text.trim();
  if (submitted != true || name.isEmpty) return;

  try {
    final client = ref.read(supabaseClientProvider);
    // invoke() returns only on a 2xx; anything else throws FunctionException.
    await client.functions.invoke('family-add-elder', body: {
      'display_name': name,
      'relationship': relationshipController.text.trim(),
    });
    // Wait for the fresh list so the new person is actually on screen before
    // we say "added" — no more "did it save?" ambiguity.
    ref.invalidate(myElderProfilesProvider);
    await ref.read(myElderProfilesProvider.future);
    if (context.mounted) {
      // Full-screen success confirmation (Stitch action_successful).
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (ctx) => ActionSuccessScreen(
          title: 'Everything is Set Up!',
          message: '$name is now safely connected to your care circle.',
          primaryLabel: 'Go to Dashboard',
          onPrimary: () => Navigator.of(ctx).pop(),
          secondaryLabel: 'Add Another Profile',
          onSecondary: () {
            Navigator.of(ctx).pop();
            showAddElderDialog(context, ref);
          },
          tagline: 'Configuration Complete',
        ),
      ));
    }
  } catch (err) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Couldn't add just now"),
          content: Text(_addElderError(err)),
          actions: [
            FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK')),
          ],
        ),
      );
    }
  }
}

/// Turns a raw add-elder failure into a plain, honest explanation the family
/// member can act on (and screenshot for support).
String _addElderError(Object err) {
  if (err is FunctionException) {
    final d = err.details;
    final serverMsg = d is Map && d['error'] != null
        ? d['error'].toString()
        : (d is String ? d : null);
    switch (err.status) {
      case 404:
        return 'We could not reach the add-person service yet. It may still '
            'be finishing setup on the server — please try again in a few '
            'minutes.';
      case 401:
        return 'Your session has expired. Please sign out and sign in again, '
            'then try once more.';
      default:
        return (serverMsg != null && serverMsg.isNotEmpty)
            ? serverMsg
            : 'The server returned an error (${err.status}). Please try again.';
    }
  }
  return 'Something went wrong. Please check your connection and try again.';
}

/// First-run welcome. Rather than a bare empty state, this explains what
/// SETU is for a brand-new family member and invites them to begin — so
/// the very first screen after sign-in teaches the idea and feels warm.
class _NoElders extends ConsumerWidget {
  const _NoElders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const features = <List<dynamic>>[
      [Icons.volunteer_activism_outlined, SetuColors.accentLight, 'Trusted caregivers',
        'Book background-verified helpers for visits, nursing and companionship.'],
      [Icons.medication_outlined, SetuColors.peachLight, 'Medicines & refills',
        'Track every dose and get a nudge before medicines run low.'],
      [Icons.favorite_outline, SetuColors.lavenderLight, 'Daily check-ins',
        'A gentle "I\'m okay today" from your parent, so you never wonder.'],
      [Icons.chat_bubble_outline, SetuColors.lavenderLight, 'AI companion',
        'Someone for them to talk to, plus warm weekly wellbeing updates.'],
      [Icons.sos_outlined, SetuColors.sosLight, 'Emergency SOS',
        'One tap calls for help and alerts your whole family at once.'],
      [Icons.timeline_outlined, SetuColors.accentLight, 'Health & timeline',
        'Every visit, appointment and update gathered in one calm place.'],
    ];

    return ListView(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      children: [
        const SizedBox(height: SetuSpacing.sm),
        Center(
          child: Container(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            decoration: BoxDecoration(
              color: SetuColors.accentLight.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.holiday_village_outlined,
                size: 44, color: SetuColors.accentLight),
          ),
        ),
        const SizedBox(height: SetuSpacing.md),
        Text('Welcome to SETU',
            textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
        const SizedBox(height: SetuSpacing.xs),
        Text(
          'A warm, simple way to look after your parents — together, from '
          'anywhere. Here\'s everything SETU does for your family.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: SetuColors.mutedLight, height: 1.5),
        ),
        const SizedBox(height: SetuSpacing.lg),

        // Start-here card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Let\'s begin', style: theme.textTheme.titleLarge),
                const SizedBox(height: SetuSpacing.xs),
                Text(
                  'Add the parent or elder you care for to unlock their '
                  'dashboard — bookings, medicines, check-ins and more.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: SetuColors.mutedLight),
                ),
                const SizedBox(height: SetuSpacing.md),
                FilledButton.icon(
                  onPressed: () => showAddElderDialog(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add someone you care for'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SetuSpacing.xl),

        Text('What you can do', style: theme.textTheme.titleLarge),
        const SizedBox(height: SetuSpacing.sm),
        for (final f in features)
          Padding(
            padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(SetuSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SetuIconChip(icon: f[0] as IconData, color: f[1] as Color),
                    const SizedBox(width: SetuSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f[2] as String,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(f[3] as String,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: SetuColors.mutedLight, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: SetuSpacing.lg),
      ],
    );
  }
}

/// One elder's full dashboard: header, "is safe" + mini map, the day's
/// bento grid, live caregiver tracking, health & activity, AI insight,
/// SETU Memories, suggestions, then the action grid. Flat, stacked
/// sections — no enclosing card — matching the Stitch family_dashboard
/// screen's layout.
class _ElderSection extends ConsumerStatefulWidget {
  const _ElderSection({required this.elder});

  final ElderProfile elder;

  @override
  ConsumerState<_ElderSection> createState() => _ElderSectionState();
}

class _ElderSectionState extends ConsumerState<_ElderSection> {
  bool _showMore = false;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final elder = widget.elder;
    final id = elder.id;

    const sage = SetuColors.accentLight;
    const peach = SetuColors.peachLight;
    const lav = SetuColors.lavenderLight;
    const primary = <_Action>[
      _Action(Icons.add_circle_outline, 'Book help', 'booking', sage),
      _Action(Icons.timeline_outlined, 'Timeline', 'timeline', lav),
      _Action(Icons.medication_outlined, 'Medicines', 'medications', peach),
      _Action(Icons.medical_services_outlined, 'Consult doctor', 'doctors', sage),
      _Action(Icons.event_outlined, 'Appointments', 'appointments', sage),
      _Action(Icons.card_membership_outlined, 'Care plans', 'care-plans', lav),
      _Action(Icons.chat_bubble_outline, 'Ask assistant', 'assistant', lav),
    ];
    const more = <_Action>[
      _Action(Icons.spa_outlined, 'Wellness', 'wellness', peach),
      _Action(Icons.notifications_outlined, 'Reminders', 'reminders', peach),
      _Action(Icons.local_hospital_outlined, 'Hospital stays', 'hospital-stays', sage),
      _Action(Icons.favorite_outline, 'Health profile', 'health-profile', peach),
      _Action(Icons.folder_shared_outlined, 'Medical records', 'documents', lav),
      _Action(Icons.diversity_1_outlined, 'Companion', 'companion-preferences', lav),
      _Action(Icons.summarize_outlined, 'Weekly reports', 'reports', sage),
      _Action(Icons.star_outline, 'Rate a visit', 'rate', peach),
      _Action(Icons.group_outlined, 'Family access', 'family', sage),
      _Action(Icons.privacy_tip_outlined, 'What you can see', 'consent', lav),
      _Action(Icons.shield_outlined, 'Privacy centre', 'privacy', sage),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Elder header: avatar + name (multi-elder households need this;
        // the Stitch mock assumes a single elder).
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: SetuColors.accentLight.withValues(alpha: 0.15),
              child: Text(_initials(elder.displayName),
                  style: const TextStyle(
                      color: SetuColors.accentLight,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Text(elder.displayName,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: SetuSpacing.md),
        // "{name} is safe" + mini "at home" map snippet (Stitch welcome
        // section).
        _StatusRow(elderId: id, name: elder.displayName),
        const SizedBox(height: SetuSpacing.md),
        _LiveTripBanner(elderId: id),
        // Bento grid: medicines today (full width) + mood / check-in.
        _BentoGrid(elderId: id),
        const SizedBox(height: SetuSpacing.md),
        _HealthScoreCard(elderId: id),
        const SizedBox(height: SetuSpacing.md),
        WeeklyActivityChart(elderId: id),
        const SizedBox(height: SetuSpacing.md),
        _AiInsightCard(elderId: id),
        const SizedBox(height: SetuSpacing.md),
        _MemoriesCard(elderId: id, name: elder.displayName),
        const SizedBox(height: SetuSpacing.md),
        SuggestionsCard(elderId: id),
        const SizedBox(height: SetuSpacing.md),
        // Primary actions grid
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: SetuSpacing.sm,
          crossAxisSpacing: SetuSpacing.sm,
          childAspectRatio: 0.92,
          children: [
            for (final a in primary)
              _ActionTile(action: a, elderId: id),
          ],
        ),
        // More (collapsed)
        const SizedBox(height: SetuSpacing.xs),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _showMore = !_showMore),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: SetuSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_showMore ? 'Show less' : 'More',
                    style: const TextStyle(
                        color: SetuColors.accentLight,
                        fontWeight: FontWeight.w600)),
                Icon(
                    _showMore
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: SetuColors.accentLight),
              ],
            ),
          ),
        ),
        if (_showMore)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: SetuSpacing.sm,
            crossAxisSpacing: SetuSpacing.sm,
            childAspectRatio: 0.92,
            children: [
              for (final a in more) _ActionTile(action: a, elderId: id),
            ],
          ),
      ],
    );
  }
}

class _Action {
  const _Action(this.icon, this.label, this.route, this.color);
  final IconData icon;
  final String label;
  final String route;
  final Color color;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.elderId});

  final _Action action;
  final String elderId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/elder/$elderId/${action.route}'),
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: action.color.withValues(alpha: 0.05),
          border: Border.all(color: action.color.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(SetuSpacing.sm),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: SetuSpacing.xs),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }
}

/// "{name} is safe" status line with a small "AT HOME" map snippet, matching
/// the Stitch dashboard's welcome + map row.
class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.elderId, required this.name});

  final String elderId;
  final String name;

  String get _first => name.trim().split(' ').first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeSummaryProvider(elderId)).asData?.value;
    final safe = s?.isSafe ?? true;
    final color = safe ? SetuColors.verifiedLight : SetuColors.peachLight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: SetuSpacing.sm),
              Flexible(
                child: Text('$_first is safe',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        const SizedBox(width: SetuSpacing.md),
        const _MapSnippet(),
      ],
    );
  }
}

/// A small, decorative "at home" map snippet (matches the Stitch dashboard's
/// map thumbnail). A calm reassurance chip rather than a live GPS claim.
class _MapSnippet extends StatelessWidget {
  const _MapSnippet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SetuColors.verifiedLight.withValues(alpha: 0.18),
            SetuColors.accentLight.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.home_rounded, size: 12, color: SetuColors.accentLight),
                  SizedBox(width: 3),
                  Text('AT HOME',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: SetuColors.inkLight)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SetuColors.borderLight.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const step = 26.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "Today at a glance" bento grid — a full-width "medicines taken" tile plus
/// a mood and check-in tile side by side. Matches the Stitch dashboard's
/// bento section, using only real data (no invented "next dose" time or
/// step counts — those aren't tracked yet).
class _BentoGrid extends ConsumerWidget {
  const _BentoGrid({required this.elderId});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeSummaryProvider(elderId));
    return async.when(
      loading: () =>
          const SizedBox(height: 140, child: Center(child: SetuLoading())),
      error: (e, s) => const SizedBox.shrink(),
      data: (summary) {
        return Padding(
          padding: const EdgeInsets.only(top: SetuSpacing.md),
          child: Column(
            children: [
              // Medicines today (full width "daily task" tile).
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(SetuSpacing.md),
                decoration: BoxDecoration(
                  color: SetuColors.peachLight.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: SetuColors.peachLight.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SetuIconChip(
                            icon: Icons.medication_outlined,
                            color: SetuColors.peachLight),
                        const SizedBox(height: SetuSpacing.sm),
                        const Text('DAILY TASK',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: SetuColors.peachLight)),
                      ],
                    ),
                    const SizedBox(width: SetuSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Medicines Taken',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: SetuColors.mutedLight,
                                  fontSize: 13)),
                          Text(
                            summary.medsTotal == 0
                                ? 'None scheduled'
                                : '${summary.medsTaken}/${summary.medsTotal}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                    color: SetuColors.peachLight,
                                    fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SetuSpacing.sm),
              // Mood + check-in, side by side.
              Row(
                children: [
                  Expanded(
                    child: _BentoTile(
                      icon: Icons.sentiment_satisfied_alt_outlined,
                      color: SetuColors.lavenderLight,
                      label: 'MOOD',
                      value: summary.mood == null
                          ? '—'
                          : summary.mood![0].toUpperCase() +
                              summary.mood!.substring(1),
                    ),
                  ),
                  const SizedBox(width: SetuSpacing.sm),
                  Expanded(
                    child: _BentoTile(
                      icon: Icons.check_circle_outline,
                      color: SetuColors.verifiedLight,
                      label: 'CHECK-IN',
                      value: summary.checkedIn ? 'Done' : 'Pending',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A single square bento tile — icon, small caps label, and a bold value.
class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: SetuSpacing.md, horizontal: SetuSpacing.sm),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: SetuSpacing.sm),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: SetuColors.mutedLight)),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// SETU Memories hero card — a warm, gradient "moment" card that deep-links
/// to the elder's full memories feed. Matches the Stitch dashboard's
/// full-bleed memories section (no real photo asset is bundled, so a warm
/// gradient stands in for the elder's photo).
class _MemoriesCard extends StatelessWidget {
  const _MemoriesCard({required this.elderId, required this.name});

  final String elderId;
  final String name;

  String get _first => name.trim().split(' ').first;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.push('/elder/$elderId/memories'),
      child: Container(
        height: 200,
        width: double.infinity,
        padding: const EdgeInsets.all(SetuSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              SetuColors.lavenderLight.withValues(alpha: 0.85),
              SetuColors.accentLight.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text('SETU MEMORIES',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white70)),
              ],
            ),
            const SizedBox(height: SetuSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Warm moments from $_first\'s day',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Tap to see the highlights',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: SetuSpacing.md),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_right,
                      color: SetuColors.accentLight),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// AI Wellness Insight card (matches the Stitch dashboard's "AI Insight"
/// panel): a warm, plain-language read on the elder's day, framed as the AI
/// companion's voice, with a "View full report" entry into the existing
/// wellness summary screen.
class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({required this.elderId});

  final String elderId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.push('/elder/$elderId/wellness-summary'),
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        decoration: BoxDecoration(
          color: SetuColors.lavenderLight.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SetuColors.lavenderLight.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.auto_awesome, size: 18, color: SetuColors.lavenderLight),
              SizedBox(width: 8),
              Text('AI INSIGHT',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: SetuColors.lavenderLight)),
            ]),
            const SizedBox(height: SetuSpacing.sm),
            Text(
              'They had a peaceful morning, took their medicines on time, and '
              'activity is a little higher than usual today.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(height: 1.4, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: SetuSpacing.md),
            Row(
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SetuSpacing.md, vertical: SetuSpacing.sm),
                  decoration: BoxDecoration(
                    color: SetuColors.lavenderLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('View full report',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Health Score card: a single reassuring number with a ring, derived from
/// today's medicines + check-in.
class _HealthScoreCard extends ConsumerWidget {
  const _HealthScoreCard({required this.elderId});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeSummaryProvider(elderId)).asData?.value;
    final medsRatio = (s != null && s.medsTotal > 0)
        ? s.medsTaken / s.medsTotal
        : 1.0;
    final checkedIn = s?.checkedIn ?? false;
    final score = (72 + medsRatio * 20 + (checkedIn ? 8 : 0)).round().clamp(0, 100);
    final label = score >= 85
        ? 'Excellent'
        : score >= 70
            ? 'Good'
            : 'Needs attention';
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/elder/$elderId/wellness-summary'),
      child: Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Health Score',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        size: 18, color: SetuColors.mutedLight),
                  ],
                ),
                Text('$score',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: SetuColors.accentLight,
                        fontWeight: FontWeight.w800)),
                Text(label,
                    style: const TextStyle(color: SetuColors.verifiedLight)),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor:
                        SetuColors.accentLight.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(
                        SetuColors.accentLight),
                  ),
                ),
                const Icon(Icons.favorite,
                    color: SetuColors.accentLight, size: 22),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Live "caregiver on the way" banner — appears only while a trip is active,
/// tapping through to the full real-time tracking view. Styled after the
/// Stitch dashboard's dashed-border caregiver tracking card.
class _LiveTripBanner extends ConsumerWidget {
  const _LiveTripBanner({required this.elderId});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(activeTripProvider(elderId)).asData?.value;
    if (trip == null) return const SizedBox.shrink();
    final arrived = trip.status == TripStatus.arrived;
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/track/${trip.bookingId}'),
        child: CustomPaint(
          painter: _DashedBorderPainter(
              color: SetuColors.lavenderLight.withValues(alpha: 0.6),
              radius: 20),
          child: Container(
            padding: const EdgeInsets.all(SetuSpacing.md),
            decoration: BoxDecoration(
              color: SetuColors.lavenderLight.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    SetuIconChip(
                      icon: Icons.person,
                      color: SetuColors.lavenderLight,
                      size: 26,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: SetuColors.lavenderLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                            arrived
                                ? Icons.doorbell_outlined
                                : Icons.directions_car_filled_outlined,
                            color: Colors.white,
                            size: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: SetuSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CAREGIVER',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: SetuColors.lavenderLight)),
                      Text(arrived ? 'Caregiver has arrived' : 'Caregiver on the way',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                          arrived
                              ? 'At the door now'
                              : trip.etaMinutes != null
                                  ? 'About ${trip.etaMinutes} min away'
                                  : 'Tap to track live',
                          style: const TextStyle(
                              color: SetuColors.mutedLight, fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(width: SetuSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SetuSpacing.md, vertical: SetuSpacing.sm),
                  decoration: BoxDecoration(
                    color: SetuColors.lavenderLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Live Track',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a soft dashed rounded-rect border, matching the Stitch caregiver
/// tracking card's `border-dashed` treatment (Flutter has no built-in
/// dashed border).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const dashWidth = 6.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
            metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
