import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../wellness/presentation/weekly_activity_chart.dart';
import '../data/medications_repository.dart';
import '../../../core/illustrations.dart';
import '../../../core/local_reminders.dart';

final _medicationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  final medications = await MedicationsRepository(client).fetchMedications(elderId);

  // Re-arm the phone's alarms from whatever the server now says. This provider
  // is invalidated whenever a medicine is added, edited or stopped, so the
  // alarms follow the medicine list without anything else having to remember
  // to keep them in step — and a stopped medicine stops reminding within a
  // single screen refresh rather than at the next reboot.
  //
  // Deliberately not awaited: a slow or refused notification permission must
  // never hold up the list somebody opened the app to read.
  unawaited(() async {
    try {
      final doses = await MedicationsRepository(client).fetchUpcomingDoses(elderId);
      await LocalReminders(client).syncDoses(doses);
    } catch (err) {
      debugPrint('Could not re-arm dose alarms: $err');
    }
  }());

  return medications;
});

/// Medicine Management + Medicine Refill Management (PRD Part 5, Batch 2,
/// Modules 5-6) — refill status shown inline per medication, deliberately
/// not a separate screen (PRD §06: "not to fragment 'medications' into
/// two disconnected app sections").
///
/// Dose generation (medications-generate-doses) and reminder delivery
/// (reminders-dispatch-sweep) are server-side; this screen only reads
/// what those produced and marks doses.
class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicationsAsync = ref.watch(_medicationsProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMedicationDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add medication'),
      ),
      body: medicationsAsync.when(
        data: (medications) {
          if (medications.isEmpty) {
            return SetuEmptyState(
              artwork: SetuArt.emptyCare(),
              icon: Icons.medication_outlined,
              title: 'No medicines yet',
              message: 'Add a medicine to track doses and refills.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              MedicationAdherenceChart(elderId: elderId),
              const SizedBox(height: SetuSpacing.lg),
              for (final medication in medications) ...[
                _MedicationCard(elderId: elderId, medication: medication),
                const SizedBox(height: SetuSpacing.md),
              ],
            ],
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }

  Future<void> _showAddMedicationDialog(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_AddMedResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SetuColors.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _AddMedicationSheet(),
    );

    if (result == null || result.name.trim().isEmpty) return;

    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final repo = MedicationsRepository(client);
      final medicationId = await repo.addMedication(
        elderId: elderId,
        name: result.name.trim(),
        dosage: result.dosage,
        times: result.times,
        addedBy: userId,
      );
      // Only when a count was given. Inventing a starting quantity would make
      // the refill warning fire on a schedule that has nothing to do with the
      // actual strip.
      final onHand = result.stockOnHand;
      if (onHand != null) {
        await repo.setStock(
          medicationId: medicationId,
          quantityOnHand: onHand,
          unit: 'tablets',
          refillThreshold: _AddMedicationSheetState._refillThresholdFor(onHand),
        );
      }
      ref.invalidate(_medicationsProvider(elderId));
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add medication: $err')));
      }
    }
  }
}

class _AddMedResult {
  const _AddMedResult(this.name, this.dosage, this.times, this.stockOnHand);
  final String name;
  final String dosage;
  final List<String> times;

  /// Null when the person didn't know or didn't say — in which case no stock
  /// row is created and the form says plainly that refill alerts are off.
  final double? stockOnHand;
}

/// Add-medication form built to match the Stitch `add_medication` design
/// (both frames): a hero banner, a split amount+unit dosage entry, the
/// Morning / Afternoon / Evening / Night grid that sets the dose times, and a
/// note on the reminder + refill-alert behaviour SETU runs automatically.
/// Submits through the same repository as before — the amount+unit split is
/// purely a visual/entry convenience, composed back into the single dosage
/// string the backend already expects.
///
/// The Stitch mock's frame 2 also shows a fabricated "AI SUGGESTION: Take
/// with food..." card — there's no real per-medicine advice engine behind
/// that (and a wrong guess here would be a safety issue, not just a UI
/// nit), so it's omitted rather than invented.
class _AddMedicationSheet extends StatefulWidget {
  const _AddMedicationSheet();

  @override
  State<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<_AddMedicationSheet> {
  final _name = TextEditingController();
  final _dosageAmount = TextEditingController();
  /// How many are in the strip or bottle right now. Optional, but without it
  /// there is no stock row and "Refill Alerts" can never fire — which is why
  /// that promise was empty for every medicine added through this sheet.
  final _stockOnHand = TextEditingController();
  String _dosageUnit = 'mg';

  /// Which parts of the day this medicine is taken. Replaces a
  /// once/twice/thrice frequency picker, which could only express four
  /// preset patterns and told the family nothing about *when*.
  ///
  /// Four independent slots express fifteen combinations instead of four, and
  /// they match how the dose is actually described at home — "the white one
  /// after breakfast and before bed" — rather than making somebody translate
  /// that into "twice daily" and hope the app picks the same hours. An empty
  /// selection is "as needed", which is the honest reading of a medicine with
  /// no fixed time.
  final Set<String> _slots = {'morning', 'night'};

  static const _units = ['mg', 'ml', 'mcg', 'tablet(s)', 'drop(s)', 'puff(s)'];

  /// Slot → 24h dose time. These are the hours the reminder sweep will fire,
  /// so they are deliberately ordinary: a dose scheduled at 06:00 because the
  /// app called it "morning" is a notification nobody wanted.
  static const _slotTimes = {
    'morning': '08:00',
    'afternoon': '14:00',
    'evening': '18:00',
    'night': '21:00',
  };

  static const _slotOrder = ['morning', 'afternoon', 'evening', 'night'];

  static const _slotLabels = {
    'morning': 'Morning',
    'afternoon': 'Afternoon',
    'evening': 'Evening',
    'night': 'Night',
  };

  static const _slotIcons = {
    'morning': Icons.wb_sunny_outlined,
    'afternoon': Icons.light_mode_outlined,
    'evening': Icons.wb_twilight,
    'night': Icons.bedtime_outlined,
  };

  List<String> get _times => [
        for (final slot in _slotOrder)
          if (_slots.contains(slot)) _slotTimes[slot]!,
      ];

  @override
  void dispose() {
    _name.dispose();
    _dosageAmount.dispose();
    _stockOnHand.dispose();
    super.dispose();
  }

  double? get _stockCount {
    final value = double.tryParse(_stockOnHand.text.trim());
    return value != null && value > 0 ? value : null;
  }

  /// Warn with roughly a week left, or a fifth of the pack, whichever is
  /// larger. A fixed number would be wrong at both ends — a warning at 5 is
  /// too late for four-a-day and far too early for a monthly tablet.
  static double _refillThresholdFor(double onHand) {
    final fifth = onHand / 5;
    return fifth < 5 ? 5 : fifth.roundToDouble();
  }

  String get _dosage {
    final amount = _dosageAmount.text.trim();
    return amount.isEmpty ? '' : '$amount $_dosageUnit';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final times = _times;
    return Padding(
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
            Text('Add New Medication',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: SetuSpacing.md),
            // Hero banner (matches the Stitch design's purple info panel).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: SetuSpacing.lg, horizontal: SetuSpacing.md),
              decoration: BoxDecoration(
                color: SetuColors.lavenderLight.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: SetuColors.lavenderLight.withValues(alpha: 0.18),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.medication_rounded,
                        color: SetuColors.lavenderLight, size: 28),
                  ),
                  const SizedBox(height: SetuSpacing.sm),
                  const Text('Keep track of your health with ease.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: SetuColors.lavenderLight,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: SetuSpacing.lg),
            const Text('Medicine Name',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: SetuSpacing.sm),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration:
                  const InputDecoration(hintText: 'e.g. Amlodipine'),
            ),
            const SizedBox(height: SetuSpacing.md),
            const Text('Dosage',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: SetuSpacing.sm),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _dosageAmount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'e.g. 5'),
                  ),
                ),
                const SizedBox(width: SetuSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _dosageUnit,
                    items: [
                      for (final u in _units)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _dosageUnit = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: SetuSpacing.md),
            const Text('When is it taken?',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: SetuSpacing.sm),
            Row(
              children: [
                for (final slot in _slotOrder) ...[
                  Expanded(child: _slotTile(slot)),
                  if (slot != _slotOrder.last)
                    const SizedBox(width: SetuSpacing.sm),
                ],
              ],
            ),
            const SizedBox(height: SetuSpacing.sm),
            // The exact hours, spelled out. The grid is the friendly way to
            // choose; this is the line that stops anyone being surprised by
            // when the phone actually goes off.
            Text(
              times.isEmpty
                  ? 'As needed — no reminders will be sent.'
                  : 'Reminders at ${times.join(', ')}.',
              style: const TextStyle(
                  color: SetuColors.mutedLight, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: SetuSpacing.md),
            // These describe what SETU actually does, and one of them used to
            // not. "Voice Reminders — friendly spoken prompts" was in the
            // Stitch design and was copied straight in; nothing in this app
            // speaks. There is no text-to-speech dependency, no audio, no
            // spoken anything. Promising an elder that a voice will remind
            // them to take a tablet, and then staying silent, is a promise
            // that fails at exactly the moment it matters.
            //
            // What actually happens is a push notification, dispatched by
            // reminders-dispatch-sweep. So that is what it now says.
            const Text('How many do you have?',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: SetuSpacing.sm),
            TextField(
              controller: _stockOnHand,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Tablets left (optional)',
                helperText: 'Needed for refill alerts. Skip if you are not sure.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: SetuSpacing.md),
            _autoFeatureRow(
              Icons.notifications_active_outlined,
              'Dose Reminders',
              times.isEmpty
                  ? 'No times chosen, so nothing will be sent. Pick a part of '
                      'the day above.'
                  : 'Your phone will remind you at ${times.join(', ')}.',
              on: times.isNotEmpty,
            ),
            const SizedBox(height: SetuSpacing.sm),
            _autoFeatureRow(
              Icons.notification_important_outlined,
              'Refill Alerts',
              _stockCount == null
                  ? 'Enter how many you have and CareHive will warn you before '
                      'they run out.'
                  : 'A warning appears once you are down to '
                      '${_refillThresholdFor(_stockCount!).toStringAsFixed(0)}.',
              on: _stockCount != null,
            ),
            const SizedBox(height: SetuSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context)
                    .pop(_AddMedResult(_name.text, _dosage, times, _stockCount)),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Medicine'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotTile(String slot) {
    final selected = _slots.contains(slot);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() {
        if (!_slots.remove(slot)) _slots.add(slot);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: SetuSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? SetuColors.accentLight
              : SetuColors.paperRaisedLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  selected ? SetuColors.accentLight : SetuColors.borderLight,
              width: 2),
        ),
        child: Column(
          children: [
            Icon(_slotIcons[slot],
                size: 22,
                color: selected ? Colors.white : SetuColors.mutedLight),
            const SizedBox(height: 4),
            Text(
              _slotLabels[slot]!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : SetuColors.inkLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A statement about what CareHive will do, not a setting.
  ///
  /// These rows used to end in `Switch(value: true, onChanged: null)`. A
  /// disabled switch renders grey, so both read as OFF — telling somebody
  /// their medicine reminders were switched off when they were always on — and
  /// tapping them did nothing, because there was never a setting behind them.
  /// A control that cannot be operated should not look like a control.
  ///
  /// Now it shows the real state: [on] is computed from what the form actually
  /// contains, so the row changes as you fill it in.
  Widget _autoFeatureRow(
    IconData icon,
    String title,
    String subtitle, {
    required bool on,
  }) {
    final colour = on ? SetuColors.verifiedLight : SetuColors.mutedLight;
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: SetuColors.lavenderLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: SetuColors.lavenderLight, size: 22),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: const TextStyle(
                        color: SetuColors.mutedLight, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: SetuSpacing.sm),
          Icon(on ? Icons.check_circle : Icons.remove_circle_outline,
              color: colour, size: 22),
        ],
      ),
    );
  }
}

class _MedicationCard extends ConsumerStatefulWidget {
  const _MedicationCard({required this.elderId, required this.medication});

  final String elderId;
  final Map<String, dynamic> medication;

  @override
  ConsumerState<_MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends ConsumerState<_MedicationCard> {
  late Future<List<Map<String, dynamic>>> _dosesFuture;
  late Future<Map<String, dynamic>?> _stockFuture;

  MedicationsRepository get _repo => MedicationsRepository(ref.read(supabaseClientProvider));
  String get _medicationId => widget.medication['id'] as String;

  @override
  void initState() {
    super.initState();
    _dosesFuture = _repo.fetchDosesForToday(_medicationId);
    _stockFuture = _repo.fetchStock(_medicationId);
  }

  void _refresh() {
    setState(() {
      _dosesFuture = _repo.fetchDosesForToday(_medicationId);
      _stockFuture = _repo.fetchStock(_medicationId);
    });
  }

  Future<void> _markDose(String doseId, String status) async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final elderAsync = await ref.read(elderProfileByIdProvider(widget.elderId).future);
    final isElderSelf = elderAsync?['auth_user_id'] == userId;
    await _repo.markDose(
      doseId: doseId,
      status: status,
      markedBy: userId,
      markedVia: isElderSelf ? 'elder_self' : 'family_proxy',
    );
    _refresh();
  }

  Future<void> _discontinue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discontinue ${widget.medication['name']}?'),
        content: const Text('Any pending doses will be cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Discontinue')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.discontinue(_medicationId);
    ref.invalidate(_medicationsProvider(widget.elderId));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SetuIconChip(icon: Icons.medication_outlined),
                const SizedBox(width: SetuSpacing.sm),
                Expanded(
                  child: Text('${widget.medication['name']} — ${widget.medication['dosage']}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Discontinue',
                  onPressed: _discontinue,
                ),
              ],
            ),
            FutureBuilder<Map<String, dynamic>?>(
              future: _stockFuture,
              builder: (context, snapshot) {
                final stock = snapshot.data;
                if (stock == null) return const SizedBox.shrink();
                final onHand = (stock['quantity_on_hand'] as num).toDouble();
                final threshold = (stock['refill_threshold'] as num).toDouble();
                final low = onHand <= threshold;
                return Padding(
                  padding: const EdgeInsets.only(top: SetuSpacing.xs),
                  child: Row(
                    children: [
                      Text('${onHand.toStringAsFixed(0)} ${stock['unit']} left',
                          style: TextStyle(color: low ? SetuColors.accentLight : null)),
                      if (low) ...[
                        const SizedBox(width: SetuSpacing.sm),
                        TextButton(
                          onPressed: () => context.push('/elder/${widget.elderId}/booking'),
                          child: const Text('Book Medicine Pickup'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: SetuSpacing.sm),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _dosesFuture,
              builder: (context, snapshot) {
                final doses = snapshot.data ?? [];
                if (doses.isEmpty) {
                  return const Text('No doses scheduled today.',
                      style: TextStyle(fontStyle: FontStyle.italic));
                }
                return Column(
                  children: doses.map((dose) {
                    final time = DateTime.parse(dose['scheduled_at'] as String).toLocal();
                    final status = dose['status'] as String;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        status == 'taken' ? Icons.check_circle : Icons.circle_outlined,
                        color: status == 'taken' ? SetuColors.verifiedLight : null,
                      ),
                      title: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
                      trailing: status == 'pending'
                          ? Wrap(spacing: 4, children: [
                              TextButton(onPressed: () => _markDose(dose['id'] as String, 'taken'), child: const Text('Taken')),
                              TextButton(onPressed: () => _markDose(dose['id'] as String, 'missed'), child: const Text('Missed')),
                            ])
                          : Text(status),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
