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
import '../../../core/motion.dart';
import '../../../core/promise_card.dart';
import '../../medications/presentation/adherence.dart';
import '../data/home_summary_repository.dart';

/// Today-at-a-glance summary for an elder (medicines, mood, check-in).
final homeSummaryProvider =
    FutureProvider.family<HomeSummary, String>((ref, elderId) async {
  ref.watch(authStateProvider);
  return HomeSummaryRepository(ref.watch(supabaseClientProvider)).fetch(elderId);
});

/// The family dashboard: a warm greeting, a bento "today" grid (medicines,
/// mood, check-in), the week's real adherence, then the action grid. Consent
/// and privacy stay one tap away — trust is a feature, not a buried setting.
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
/// conditions are exactly what a doctor or a paramedic needs and nobody
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
  // Where they live. Kept because it belongs on a medical record, not because
  // it gates anything — CareHive works identically everywhere.
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
                    'Shown on the medical ID screen — the one a paramedic or '
                    'a doctor reads. You can add or change these any time.',
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
                          'We use these details to help CareHive\'s AI understand '
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

    // No region waiting-list call any more. It existed to record "tell me when
    // you reach my city", and there is nothing left to wait for — the medicine
    // record works the same everywhere.

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
      // paramedic reads off the medical ID, and they feed the health profile
      // and the SOS screen — so the moment the person is added is the only
      // moment the family is reliably willing to fill them in. It stays
      // skippable: nobody should be blocked from finishing because they
      // can't remember a blood group.
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
                      'and conditions. This is what a doctor or a paramedic '
                      'reads if something goes wrong.',
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
/// CareHive is for a brand-new family member and invites them to begin — so
/// the very first screen after sign-in teaches the idea and feels warm.
class _NoElders extends ConsumerWidget {
  const _NoElders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // One bold line each — see PromiseCard. The long-form version of this list
    // was six paragraphs, which is a page nobody reads on the one screen where
    // you are still deciding whether the app is worth your time.
    const features = <List<dynamic>>[
      [Icons.alarm_on_rounded, SetuColors.peachLight, 'Every dose, on time',
        'The phone rings on the minute, even offline.'],
      [Icons.fact_check_rounded, SetuColors.verifiedLight, 'A record that is true',
        'Taken, not taken and no record stay three separate things.'],
      [Icons.badge_rounded, SetuColors.accentLight, 'Ready for the question',
        'Medicines, allergies and blood group on one screen.'],
      [Icons.favorite_rounded, SetuColors.lavenderLight, 'Daily check-ins',
        'A gentle "I\'m okay today", so you never wonder.'],
      [Icons.sos_rounded, SetuColors.sosLight, 'Emergency SOS',
        'One tap calls for help and alerts everyone at once.'],
      [Icons.timeline_rounded, SetuColors.accentLight, 'Health & timeline',
        'Appointments and hospital stays in one calm place.'],
    ];

    return ListView(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      children: [
        const WelcomeHero(),
        const SizedBox(height: SetuSpacing.md),
        Text('Welcome to CareHive',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: SetuSpacing.xs),
        Text(
          'Know what your parent actually takes — and be able to show it.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge
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
                  'Add the parent or elder you care for, then add their '
                  'medicines. The reminders start straight away.',
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
          PromiseCard(
            icon: f[0] as IconData,
            tint: f[1] as Color,
            title: f[2] as String,
            body: f[3] as String,
            elderScale: false,
          ),
        const SizedBox(height: SetuSpacing.lg),
      ],
    );
  }
}

/// One elder's full dashboard: header, status row, the day's bento grid, the
/// week's adherence, then the action grid. Flat, stacked sections with no
/// enclosing card.
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
      _Action(Icons.medication_outlined, 'Medicines', 'medications', peach),
      // Second only to SOS. The medical ID is the screen a paramedic reads off
      // a locked phone, and it is useless if it takes four taps to find.
      _Action(Icons.badge_outlined, 'Medical ID', 'medical-id', sage),
      _Action(Icons.event_outlined, 'Appointments', 'appointments', sage),
      _Action(Icons.notifications_outlined, 'Reminders', 'reminders', peach),
      _Action(Icons.timeline_outlined, 'Timeline', 'timeline', lav),
    ];
    const more = <_Action>[
      _Action(Icons.favorite_outline, 'Health profile', 'health-profile', peach),
      _Action(Icons.folder_shared_outlined, 'Medical records', 'documents', lav),
      _Action(Icons.local_hospital_outlined, 'Hospital stays', 'hospital-stays', sage),
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
        // Bento grid: medicines today (full width) + mood / check-in.
        _BentoGrid(elderId: id),
        const SizedBox(height: SetuSpacing.md),
        // The week's actual record, and the only summary on this screen.
        //
        // What used to sit here was removed rather than reworded: a "Health
        // Score" computed as `72 + medsRatio * 20`, which could never fall
        // below 72 no matter what the app knew, and an "AI Insight" card whose
        // reassuring sentence about a peaceful morning was a hardcoded string
        // shown to every family every day. A number that reads as clinical and
        // isn't is worse than a blank space, because it gets believed.
        MedicationAdherenceChart(elderId: id),
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
    // Properly tinted tiles, matching the CareHive bento grids. These used to be
    // a 5%-alpha wash inside a hairline border, which read as grey at arm's
    // length — the designs colour the whole tile and drop the border, and the
    // difference on a real phone is the difference between a legible grid and
    // a page of faint rectangles.
    // Sinks under the finger and buzzes, on top of the ripple. A grid of
    // twelve flat tiles reads as a picture of buttons; one that moves reads as
    // buttons.
    return Pressable(
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
/// grid. CareHive knows an elder's location during an SOS and at no other moment,
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
