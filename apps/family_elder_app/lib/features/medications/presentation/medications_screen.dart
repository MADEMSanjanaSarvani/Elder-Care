import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/medications_repository.dart';

final _medicationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return MedicationsRepository(client).fetchMedications(elderId);
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
            return const SetuEmptyState(
              icon: Icons.medication_outlined,
              title: 'No medicines yet',
              message: 'Add a medicine to track doses and refills.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: medications.length,
            separatorBuilder: (context, index) => const SizedBox(height: SetuSpacing.md),
            itemBuilder: (context, index) => _MedicationCard(
              elderId: elderId,
              medication: medications[index],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Something went wrong: $err')),
      ),
    );
  }

  Future<void> _showAddMedicationDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final timesController = TextEditingController(text: '08:00, 20:00');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add medication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: SetuSpacing.sm),
            TextField(controller: dosageController, decoration: const InputDecoration(labelText: 'Dosage (e.g. 500mg)')),
            const SizedBox(height: SetuSpacing.sm),
            TextField(
              controller: timesController,
              decoration: const InputDecoration(labelText: 'Times (24h, comma-separated)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Add')),
        ],
      ),
    );

    if (result != true || nameController.text.trim().isEmpty) return;

    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final times = timesController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    try {
      await MedicationsRepository(client).addMedication(
        elderId: elderId,
        name: nameController.text.trim(),
        dosage: dosageController.text.trim(),
        times: times,
        addedBy: userId,
      );
      ref.invalidate(_medicationsProvider(elderId));
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add medication: $err')));
      }
    }
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
