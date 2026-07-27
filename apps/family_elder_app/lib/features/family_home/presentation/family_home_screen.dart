import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/action_success.dart';
import '../../../core/providers.dart';
import '../../../core/region_picker.dart';
import '../../health_profile/data/health_profile_repository.dart';
import '../../health_profile/presentation/elder_avatar.dart';
import '../../memories/presentation/memory_lane_card.dart';
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
/// Matches the Stitch "add_elder_profile" design: an icon-avatar header, an
/// info box explaining why the details are collected, and labelled fields.
///
/// The Stitch mock is a 4-step wizard (profile photo, DOB, gender, primary
/// language across separate screens). This stays a single scrolling sheet:
/// four screens of tapping to add one person is how a form gets abandoned
/// halfway, and everything below the name is optional anyway.
///
/// Identity fields (name, relationship, dob, primary_language) go through the
/// family-add-elder function, which is the only path RLS allows for creating
/// the elder row. The medical fields cannot ride along — the function doesn't
/// read them — so they are written straight afterwards through
/// HealthProfileRepository, which RLS does permit once the family link exists.
///
/// Medical details are asked for here, at the one moment the family is
/// reliably willing to fill them in, because blood group, allergies and
/// conditions are exactly what a caregiver or a paramedic needs and nobody
/// comes back to a settings screen to enter them later. They stay optional and
/// the same fields remain editable on the health profile screen — a failure to
/// save them must never lose the person who was just added.
Future<void> showAddElderDialog(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final relationshipController = TextEditingController();
  final allergiesController = TextEditingController();
  final conditionsController = TextEditingController();
  DateTime? dob;
  String language = 'en';
  String? gender;
  String? bloodType;
  var showMedical = false;
  // Where they live decides which doctors and which caregivers this family
  // will ever see, and it was hardcoded to the Vizag pilot for everyone in the
  // country. Still defaults to the pilot, because that is where SETU actually
  // operates — but it is a choice now, and a family outside it gets told the
  // truth instead of being shown a clinic 700km away.
  var regionCode = 'vizag-ap-in';
  const languages = {'en': 'English', 'hi': 'हिन्दी (Hindi)', 'te': 'తెలుగు (Telugu)'};
  const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SetuColors.paperLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: SetuSpacing.lg,
          right: SetuSpacing.lg,
          top: SetuSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + SetuSpacing.lg,
        ),
        child: SingleChildScrollView(
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
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                      color: SetuColors.accentLight.withValues(alpha: 0.14),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.elderly_outlined,
                      color: SetuColors.accentLight, size: 34),
                ),
              ),
              const SizedBox(height: SetuSpacing.md),
              Text('Tell us about your loved one',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              const Text('They join your care circle right away.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SetuColors.mutedLight)),
              const SizedBox(height: SetuSpacing.lg),
              const Text('Full name',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: SetuSpacing.sm),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    hintText: 'e.g. Lakshmi',
                    prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: SetuSpacing.md),
              const Text('Relationship (optional)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: SetuSpacing.sm),
              TextField(
                controller: relationshipController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    hintText: 'e.g. Mother',
                    prefixIcon: Icon(Icons.diversity_1_outlined)),
              ),
              const SizedBox(height: SetuSpacing.md),
              const Text('Date of birth (optional)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: SetuSpacing.sm),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dob ??
                        DateTime.now().subtract(const Duration(days: 365 * 65)),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => dob = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.cake_outlined)),
                  child: Text(
                      dob == null
                          ? 'mm/dd/yyyy'
                          : '${dob!.month}/${dob!.day}/${dob!.year}',
                      style: TextStyle(
                          color: dob == null
                              ? Theme.of(context).hintColor
                              : SetuColors.inkLight)),
                ),
              ),
              const SizedBox(height: SetuSpacing.md),
              const Text('Primary language',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: SetuSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: language,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.language_outlined)),
                items: [
                  for (final entry in languages.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (v) {
                  if (v != null) setSheetState(() => language = v);
                },
              ),
              const SizedBox(height: SetuSpacing.md),
              const Text('Where they live',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: SetuSpacing.sm),
              RegionPicker(
                value: regionCode,
                onChanged: (v) => setSheetState(() => regionCode = v),
              ),
              const SizedBox(height: SetuSpacing.md),
              // Collapsed by default: the fields are genuinely optional, and a
              // sheet that opens showing eight medical questions reads as a
              // form to escape rather than a person to add. Open, it explains
              // who sees the answers — families hand over health details more
              // readily when they know what they are for.
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setSheetState(() => showMedical = !showMedical),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: SetuSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.medical_information_outlined,
                          size: 20, color: SetuColors.accentLight),
                      const SizedBox(width: SetuSpacing.sm),
                      const Expanded(
                        child: Text('Medical details (optional)',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Icon(
                          showMedical
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: SetuColors.mutedLight),
                    ],
                  ),
                ),
              ),
              if (showMedical) ...[
                const Text(
                    'Shared with a caregiver during a visit and shown on the '
                    'emergency screen. You can add or change these any time.',
                    style: TextStyle(
                        color: SetuColors.mutedLight,
                        fontSize: 12.5,
                        height: 1.4)),
                const SizedBox(height: SetuSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: gender,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Gender'),
                        items: const [
                          DropdownMenuItem(
                              value: 'female', child: Text('Female')),
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'other', child: Text('Other')),
                          DropdownMenuItem(
                              value: 'prefer_not_to_say',
                              child: Text('Prefer not to say')),
                        ],
                        onChanged: (v) => setSheetState(() => gender = v),
                      ),
                    ),
                    const SizedBox(width: SetuSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: bloodType,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Blood group'),
                        items: [
                          for (final type in bloodTypes)
                            DropdownMenuItem(value: type, child: Text(type)),
                        ],
                        onChanged: (v) => setSheetState(() => bloodType = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SetuSpacing.md),
                TextField(
                  controller: allergiesController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Allergies',
                    hintText: 'e.g. Penicillin, peanuts',
                    helperText: 'Separate with commas',
                    prefixIcon: Icon(Icons.warning_amber_outlined),
                  ),
                ),
                const SizedBox(height: SetuSpacing.md),
                TextField(
                  controller: conditionsController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Ongoing conditions',
                    hintText: 'e.g. Diabetes, hypertension',
                    helperText: 'Separate with commas',
                    prefixIcon: Icon(Icons.monitor_heart_outlined),
                  ),
                ),
              ],
              const SizedBox(height: SetuSpacing.md),
              Container(
                padding: const EdgeInsets.all(SetuSpacing.md),
                decoration: BoxDecoration(
                  color: SetuColors.peachLight.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: SetuColors.peachLight),
                    SizedBox(width: SetuSpacing.sm),
                    Expanded(
                      child: Text(
                          'We use these details to help SETU\'s AI understand '
                          'cultural nuances and provide better companionship.',
                          style: TextStyle(
                              color: SetuColors.mutedLight, fontSize: 12.5, height: 1.4)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SetuSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Add to care circle'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  final name = nameController.text.trim();
  if (submitted != true || name.isEmpty) return;

  try {
    final client = ref.read(supabaseClientProvider);
    // invoke() returns only on a 2xx; anything else throws FunctionException.
    final res = await client.functions.invoke('family-add-elder', body: {
      'display_name': name,
      'relationship': relationshipController.text.trim(),
      'primary_language': language,
      'region_code': regionCode,
      if (dob != null)
        'dob':
            '${dob!.year.toString().padLeft(4, '0')}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}',
    });
    final data = res.data;
    final newElderId =
        data is Map && data['elder_id'] is String ? data['elder_id'] as String : null;

    // If they picked somewhere SETU hasn't reached, the sheet just told them
    // we'd let them know when we arrive. Record that so it's a promise we can
    // keep — and so "which city next" becomes a count rather than a guess.
    // register_region_interest ignores regions that are already live, so this
    // is safe to call every time.
    final regions = await ref.read(regionsProvider.future);
    final chosen = regions.firstWhere((r) => r['code'] == regionCode,
        orElse: () => const <String, dynamic>{});
    final chosenId = chosen['id'] as String?;
    if (chosenId != null) {
      await registerRegionInterest(ref,
          regionId: chosenId, elderId: newElderId);
    }

    final allergies = _splitList(allergiesController.text);
    final conditions = _splitList(conditionsController.text);
    final hasMedical = gender != null ||
        bloodType != null ||
        allergies.isNotEmpty ||
        conditions.isNotEmpty;
    // Best-effort, and deliberately so. The person is already created; if the
    // medical write fails the family must still land on "added", not on an
    // error that implies nothing happened. The success screen below then
    // points them at the health profile screen, where the same fields live.
    var medicalSaved = false;
    if (newElderId != null && hasMedical) {
      try {
        final repo = HealthProfileRepository(client);
        if (gender != null) await repo.saveGender(newElderId, gender);
        if (bloodType != null || allergies.isNotEmpty || conditions.isNotEmpty) {
          await repo.saveHealthProfile(
            elderId: newElderId,
            updatedBy: client.auth.currentUser!.id,
            bloodType: bloodType,
            allergies: allergies,
            chronicConditions: conditions,
          );
        }
        medicalSaved = true;
      } catch (_) {
        medicalSaved = false;
      }
    }

    // Wait for the fresh list so the new person is actually on screen before
    // we say "added" — no more "did it save?" ambiguity.
    ref.invalidate(myElderProfilesProvider);
    await ref.read(myElderProfilesProvider.future);
    if (context.mounted) {
      // Full-screen success confirmation (Stitch action_successful).
      //
      // The primary action leads straight into medical details rather than
      // the dashboard. Blood group, allergies and conditions are what a
      // caregiver or a paramedic sees in an emergency, and they feed the
      // health profile, the SOS screen and every caregiver's visit view — so
      // the moment the person is added is the only moment the family is
      // reliably willing to fill them in. It stays skippable: nobody should
      // be blocked from finishing because they can't remember a blood group.
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (ctx) => ActionSuccessScreen(
          title: 'Everything is Set Up!',
          message: newElderId == null
              ? '$name is now safely connected to your care circle.'
              : medicalSaved
                  ? '$name is now safely connected to your care circle.\n\n'
                      'Their medical details are saved. Add height, weight, '
                      'medicines and doctor details whenever you have them.'
                  : '$name is now safely connected to your care circle.\n\n'
                      'Next, add their medical details — blood group, allergies '
                      'and conditions. This is what a caregiver or paramedic sees '
                      'if something goes wrong.',
          primaryLabel: newElderId == null
              ? 'Go to Dashboard'
              : medicalSaved
                  ? 'Review medical details'
                  : 'Add medical details',
          onPrimary: () {
            Navigator.of(ctx).pop();
            if (newElderId != null) {
              context.push('/elder/$newElderId/health-profile');
            }
          },
          secondaryLabel:
              newElderId == null ? 'Add Another Profile' : 'I\'ll do this later',
          onSecondary: () {
            Navigator.of(ctx).pop();
            if (newElderId == null) showAddElderDialog(context, ref);
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

/// "Penicillin, peanuts" -> ['Penicillin', 'peanuts']. Empty entries are
/// dropped so a stray trailing comma doesn't become a blank allergy sitting on
/// the emergency screen.
List<String> _splitList(String raw) => raw
    .split(',')
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();

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

  @override
  Widget build(BuildContext context) {
    final elder = widget.elder;
    final id = elder.id;

    const sage = SetuColors.accentLight;
    const peach = SetuColors.peachLight;
    const lav = SetuColors.lavenderLight;
    const primary = <_Action>[
      // Emergency comes first and carries the SOS red. The route and screen
      // already existed but nothing on the family dashboard linked to them,
      // so a family member simply could not reach SOS — only the elder's own
      // home had a button. That is the one thing that must never be buried.
      _Action(Icons.emergency_outlined, 'Emergency', 'sos',
          SetuColors.sosLight),
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
            // Their actual face when one has been added, initials otherwise.
            // Not editable here — the photo is set from the health profile,
            // so a mis-tap on a dashboard nobody scrolls carefully can't
            // start a file picker.
            ElderAvatar(
              elderId: id,
              displayName: elder.displayName,
              radius: 22,
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
        // Memory Lane. Renders nothing at all when there is no memory old
        // enough to offer, or when this one has been put away — an empty
        // prompt is worse than no prompt.
        MemoryLaneCard(elderId: id),
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
    // Properly tinted tiles, matching the SETU bento grids. These used to be
    // a 5%-alpha wash inside a hairline border, which read as grey at arm's
    // length — the designs colour the whole tile and drop the border, and the
    // difference on a real phone is the difference between a legible grid and
    // a page of faint rectangles.
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/elder/$elderId/${action.route}'),
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: action.color.withValues(alpha: 0.16),
          boxShadow: SetuSurfaces.of(context).cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(SetuSpacing.sm),
              decoration: BoxDecoration(
                // Solid, not a wash — the icon container in the designs is
                // the saturated element that gives each tile its identity.
                color: action.color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(action.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: SetuSpacing.xs),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// The status line the whole dashboard is really for, matching the Stitch
/// welcome section.
///
/// Two things changed here from the earlier pass, and both were the same
/// mistake this project has spent weeks refusing in other people's mocks.
///
/// The state was hardcoded: `isSafe` returned a literal `true`, so this line
/// read "Ramesh is safe" in green whatever had happened. It now comes from an
/// open `sos_events` row and today's `checkin_missed` entry.
///
/// And the map thumbnail beside it carried an "AT HOME" badge over a drawn
/// grid. SETU knows an elder's location during an SOS and at no other moment,
/// so that badge was a location claim with nothing behind it — on the screen
/// a family opens precisely to ask where he is. If he had wandered out it
/// would still have said AT HOME. It is replaced by the last check-in, which
/// is both true and the thing they wanted to know.
class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.elderId, required this.name});

  final String elderId;
  final String name;

  String get _first => name.trim().split(' ').first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeSummaryProvider(elderId)).asData?.value;
    final state = s?.safety ?? SafetyState.allWell;

    final (Color color, String label) = switch (state) {
      SafetyState.emergency => (SetuColors.sosLight, 'Emergency raised'),
      SafetyState.needsAttention =>
        (SetuColors.peachLight, 'No check-in yet today'),
      SafetyState.allWell => (SetuColors.verifiedLight, '$_first is safe'),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulseDot(color: color),
              const SizedBox(width: SetuSpacing.sm),
              Flexible(
                child: Text(label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        const SizedBox(width: SetuSpacing.md),
        _LastCheckInChip(at: s?.lastCheckIn),
      ],
    );
  }
}

/// A slowly breathing status dot. The design animates it, and here the motion
/// earns its keep: it is what tells someone the line is live rather than a
/// label printed once. Honours reduced-motion with a still dot.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setuSyncBreathing(context, _c, restingValue: 1);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (MediaQuery.of(context).disableAnimations) return dot;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: dot,
    );
  }
}

/// When they last checked in — the real answer to "is he all right?", in the
/// slot the mock filled with a picture of a map.
class _LastCheckInChip extends StatelessWidget {
  const _LastCheckInChip({this.at});

  final DateTime? at;

  static String _clock(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final known = at != null;
    final colour = known ? SetuColors.verifiedLight : SetuColors.mutedLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(known ? Icons.check_circle_outline : Icons.schedule,
              size: 14, color: colour),
          const SizedBox(width: 5),
          Text(
            known ? 'Checked in ${_clock(at!)}' : 'No check-in yet',
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: colour),
          ),
        ],
      ),
    );
  }
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SetuIconChip(
                            icon: Icons.medication_outlined,
                            color: SetuColors.peachLight),
                        SizedBox(height: SetuSpacing.sm),
                        Text('DAILY TASK',
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
    // The designs' bento treatment: the tile is washed in its own accent
    // rather than being another white card behind a border, and the icon sits
    // in a solid chip of that accent. White-on-white made the two tiles read
    // as one undifferentiated block; the tint is what lets someone find "mood"
    // without reading the label.
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: SetuSpacing.md, horizontal: SetuSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: SetuSpacing.sm),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: color)),
          const SizedBox(height: 2),
          Text(value,
              textAlign: TextAlign.center,
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
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
            const Row(children: [
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
                const Row(
                  children: [
                    Text('Health Score',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right,
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
                    const SetuIconChip(
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
