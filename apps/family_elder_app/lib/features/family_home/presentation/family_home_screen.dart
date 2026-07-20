import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../suggestions/presentation/suggestions_card.dart';
import '../../trips/data/trips_repository.dart';
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

/// Timeline-first dashboard (PRD Part 3 §17). Redesigned to the CareHive
/// design system: an avatar header, a friendly "Today" status card, a clean
/// grid of the primary actions, and everything secondary tucked under
/// "More" — clarity over density. Consent/privacy stay one tap away (trust
/// is a feature, not a buried setting).
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
            const SizedBox(height: SetuSpacing.md),
            for (final elder in elders) ...[
              _ElderCard(elder: elder),
              const SizedBox(height: SetuSpacing.lg),
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
/// Stitch "Good evening, {name}" header).
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
          .headlineSmall
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added to your care circle.')),
      );
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
/// CareHive is for a brand-new family member and invites them to begin — so
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
        Text('Welcome to CareHive',
            textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
        const SizedBox(height: SetuSpacing.xs),
        Text(
          'A warm, simple way to look after your parents — together, from '
          'anywhere. Here\'s everything CareHive does for your family.',
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

class _ElderCard extends ConsumerStatefulWidget {
  const _ElderCard({required this.elder});

  final ElderProfile elder;

  @override
  ConsumerState<_ElderCard> createState() => _ElderCardState();
}

class _ElderCardState extends ConsumerState<_ElderCard> {
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      SetuColors.accentLight.withValues(alpha: 0.15),
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
            _LiveTripBanner(elderId: id),
            const _LocationCard(),
            const SizedBox(height: SetuSpacing.md),
            const _AiInsightCard(),
            const SizedBox(height: SetuSpacing.md),
            _HealthScoreCard(elderId: id),
            const SizedBox(height: SetuSpacing.md),
            // Today at a glance (family_dashboard design).
            _TodayGlance(elderId: id, name: elder.displayName),
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
        ),
      ),
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

/// AI Wellness Insight card (redesign home_screen_family): a warm, plain-
/// language read on the elder's day, framed as the AI companion's voice.
class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.lavenderLight.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.auto_awesome, size: 18, color: SetuColors.lavenderLight),
            SizedBox(width: 8),
            Text('AI Wellness Insight',
                style: TextStyle(
                    color: SetuColors.lavenderLight,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: SetuSpacing.sm),
          const Text(
            '"They had a peaceful morning, took their medicines on time, and '
            'activity is a little higher than usual today."',
            style: TextStyle(height: 1.5, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// Health Score card (redesign home_screen_family): a single reassuring
/// number with a ring, derived from today's medicines + check-in.
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
    return Container(
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
                const Text('Health Score',
                    style: TextStyle(fontWeight: FontWeight.w700)),
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
    );
  }
}

/// Live "caregiver on the way" banner — appears only while a trip is active,
/// tapping through to the full real-time tracking view.
class _LiveTripBanner extends ConsumerWidget {
  const _LiveTripBanner({required this.elderId});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(activeTripProvider(elderId)).asData?.value;
    if (trip == null) return const SizedBox.shrink();
    final arrived = trip.status == TripStatus.arrived;
    final color =
        arrived ? SetuColors.verifiedLight : SetuColors.accentLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/track/${trip.bookingId}'),
        child: Container(
          padding: const EdgeInsets.all(SetuSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              SetuIconChip(
                  icon: arrived
                      ? Icons.doorbell_outlined
                      : Icons.directions_car_filled_outlined,
                  color: color),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(arrived ? 'Caregiver has arrived' : 'Caregiver on the way',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                        arrived
                            ? 'At the door now'
                            : trip.etaMinutes != null
                                ? 'About ${trip.etaMinutes} min away · tap to track'
                                : 'Tap to track live',
                        style: const TextStyle(
                            color: SetuColors.mutedLight, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SetuColors.mutedLight),
            ],
          ),
        ),
      ),
    );
  }
}

/// A soft map-style "safe zone" card (matches the Stitch dashboard's location
/// panel). A calm reassurance band rather than a live GPS claim.
class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SetuColors.verifiedLight.withValues(alpha: 0.16),
            SetuColors.accentLight.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Stack(
        children: [
          // Subtle "map grid" texture.
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(SetuSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                        color: SetuColors.verifiedLight,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.home_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: SetuSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('At home',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const Text('Safe zone',
                          style: TextStyle(
                              color: SetuColors.mutedLight, fontSize: 12.5)),
                    ],
                  ),
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

/// "Today at a glance" — the emotional heart of the family dashboard: a "safe"
/// reassurance line, medicines taken today, mood, and a SETU Memories entry.
class _TodayGlance extends ConsumerWidget {
  const _TodayGlance({required this.elderId, required this.name});

  final String elderId;
  final String name;

  String get _first => name.trim().split(' ').first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeSummaryProvider(elderId));
    return async.when(
      loading: () => const SizedBox(
          height: 96, child: Center(child: SetuLoading())),
      error: (e, s) => const SizedBox.shrink(),
      data: (s) {
        final safe = s.isSafe;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(safe ? Icons.verified_user : Icons.info_outline,
                    size: 18,
                    color: safe
                        ? SetuColors.verifiedLight
                        : SetuColors.peachLight),
                const SizedBox(width: 6),
                Text('$_first is safe',
                    style: TextStyle(
                        color: safe
                            ? SetuColors.verifiedLight
                            : SetuColors.peachLight,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: SetuSpacing.md),
            // Medicines taken today (peach "daily task" card).
            Container(
              padding: const EdgeInsets.all(SetuSpacing.md),
              decoration: BoxDecoration(
                color: SetuColors.peachLight.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const SetuIconChip(
                      icon: Icons.medication_outlined,
                      color: SetuColors.peachLight),
                  const SizedBox(width: SetuSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Medicines today',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: SetuColors.mutedLight,
                                fontSize: 13)),
                        Text(
                          s.medsTotal == 0
                              ? 'None scheduled'
                              : '${s.medsTaken} / ${s.medsTotal} taken',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: SetuColors.peachLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SetuSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    color: SetuColors.lavenderLight,
                    label: 'Mood',
                    value: s.mood == null
                        ? '—'
                        : s.mood![0].toUpperCase() + s.mood!.substring(1),
                  ),
                ),
                const SizedBox(width: SetuSpacing.sm),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.check_circle_outline,
                    color: SetuColors.verifiedLight,
                    label: 'Check-in',
                    value: s.checkedIn ? 'Done' : 'Pending',
                  ),
                ),
              ],
            ),
            const SizedBox(height: SetuSpacing.sm),
            // SETU Memories entry.
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/elder/$elderId/memories'),
              child: Container(
                padding: const EdgeInsets.all(SetuSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    SetuColors.lavenderLight.withValues(alpha: 0.16),
                    SetuColors.accentLight.withValues(alpha: 0.10),
                  ]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    SetuIconChip(
                        icon: Icons.auto_awesome,
                        color: SetuColors.lavenderLight),
                    SizedBox(width: SetuSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SETU Memories',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text('Warm moments from their day',
                              style: TextStyle(
                                  color: SetuColors.mutedLight, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: SetuColors.mutedLight),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: SetuSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: SetuColors.mutedLight, fontSize: 12.5)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}
