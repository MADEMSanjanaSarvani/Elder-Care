import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/visit_tools_repository.dart';

/// Batch 3 caregiver tools, embedded below the OTP controls on the visit
/// screen, matching the Stitch "visit_task_checklist" design: a card-per-
/// item checklist with a real "X of N" completed count, in place of the
/// old chip row. Everything here is visibility-gated by RLS server-side:
/// the emergency health card only comes back during an in-progress booking
/// (or dispatched SOS), and the handoff section only exists when this
/// booking is a shift of a hospital stay.
///
/// The Stitch mock's checklist is a fixed list of prescribed medical tasks
/// (specific medicine dosages, a walking route, a lunch menu) with vitals
/// and a room location in the header — none of that is tracked by SETU.
/// The real checklist here is the elder's actual logged activities
/// (`VisitToolsRepository.availableActivities`), styled the same way.
class VisitToolsSection extends ConsumerStatefulWidget {
  const VisitToolsSection({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<VisitToolsSection> createState() => _VisitToolsSectionState();
}

class _VisitToolsSectionState extends ConsumerState<VisitToolsSection> {
  Map<String, dynamic>? _healthInfo;
  Map<String, dynamic>? _stayLink;
  List<Map<String, dynamic>> _stayNotes = [];
  Set<String> _activities = {};
  String? _mood;
  final _noteController = TextEditingController();
  final _handoffController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  VisitToolsRepository get _repo =>
      VisitToolsRepository(ref.read(supabaseClientProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final booking = await client
        .from('bookings')
        .select('elder_id')
        .eq('id', widget.bookingId)
        .maybeSingle();
    final elderId = booking?['elder_id'] as String?;

    final healthInfo =
        elderId != null ? await _repo.fetchEmergencyHealthInfo(elderId) : null;
    final existingLog = await _repo.fetchActivityLog(widget.bookingId);
    final stayLink = await _repo.fetchStayForBooking(widget.bookingId);
    List<Map<String, dynamic>> stayNotes = [];
    if (stayLink != null) {
      stayNotes =
          await _repo.fetchStayShiftNotes(stayLink['hospital_stay_id'] as String);
    }

    if (!mounted) return;
    setState(() {
      _healthInfo = healthInfo;
      _stayLink = stayLink;
      _stayNotes = stayNotes;
      _activities =
          ((existingLog?['activities'] as List?)?.cast<String>() ?? []).toSet();
      _mood = existingLog?['caregiver_observed_mood'] as String?;
      _noteController.text = existingLog?['note'] as String? ?? '';
      _handoffController.text = stayLink?['shift_note'] as String? ?? '';
      _loaded = true;
    });
  }

  Future<void> _saveActivityLog() async {
    setState(() => _saving = true);
    try {
      await _repo.saveActivityLog(
        bookingId: widget.bookingId,
        activities: _activities.toList(),
        observedMood: _mood,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Activity log saved')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $err')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveHandoff() async {
    setState(() => _saving = true);
    try {
      await _repo.saveHandoffNote(widget.bookingId, _handoffController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Handoff note saved')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $err')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _activityIcons = {
    'walked': Icons.directions_walk,
    'played_a_game': Icons.extension_outlined,
    'read_together': Icons.menu_book_outlined,
    'watched_tv': Icons.tv_outlined,
    'chatted': Icons.chat_bubble_outline,
    'other': Icons.more_horiz,
  };

  String _activityLabel(String activity) {
    final words = activity.split('_');
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final total = VisitToolsRepository.availableActivities.length;
    final done = _activities.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_healthInfo != null) ...[
          const SizedBox(height: SetuSpacing.lg),
          Container(
            padding: const EdgeInsets.all(SetuSpacing.md),
            decoration: BoxDecoration(
              color: SetuColors.sosLight.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SetuColors.sosLight.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_information_outlined,
                        color: SetuColors.sosLight),
                    const SizedBox(width: SetuSpacing.sm),
                    Text('Emergency info',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: SetuSpacing.sm),
                if (_healthInfo!['blood_type'] != null)
                  Text('Blood type: ${_healthInfo!['blood_type']}'),
                if (((_healthInfo!['allergies'] as List?) ?? []).isNotEmpty)
                  Text(
                      'Allergies: ${(_healthInfo!['allergies'] as List).join(', ')}'),
                if (((_healthInfo!['chronic_conditions'] as List?) ?? [])
                    .isNotEmpty)
                  Text(
                      'Conditions: ${(_healthInfo!['chronic_conditions'] as List).join(', ')}'),
                if (_healthInfo!['emergency_medical_notes'] != null)
                  Text('Notes: ${_healthInfo!['emergency_medical_notes']}'),
              ],
            ),
          ),
        ],
        if (_stayLink != null) ...[
          const SizedBox(height: SetuSpacing.lg),
          Container(
            padding: const EdgeInsets.all(SetuSpacing.md),
            decoration: BoxDecoration(
              color: SetuColors.paperRaisedLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SetuColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Hospital stay — ${(_stayLink!['hospital_stays'] as Map<String, dynamic>?)?['hospital_name'] ?? ''}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: SetuSpacing.sm),
                for (final note in _stayNotes)
                  if (note['booking_id'] != widget.bookingId)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SetuSpacing.xs),
                      child: Text('Previous shift: ${note['shift_note']}',
                          style: const TextStyle(color: SetuColors.mutedLight)),
                    ),
                const SizedBox(height: SetuSpacing.xs),
                TextField(
                  controller: _handoffController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Handoff note for the next shift',
                  ),
                ),
                const SizedBox(height: SetuSpacing.sm),
                OutlinedButton(
                  onPressed: _saving ? null : _saveHandoff,
                  child: const Text('Save handoff note'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: SetuSpacing.lg),
        Row(
          children: [
            Text('Visit Checklist',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SetuColors.accentLight.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$done/$total',
                  style: const TextStyle(
                      color: SetuColors.accentLight, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: SetuSpacing.xs),
        const Text('What did they get up to during this visit?',
            style: TextStyle(color: SetuColors.mutedLight)),
        const SizedBox(height: SetuSpacing.md),
        for (final activity in VisitToolsRepository.availableActivities)
          _ChecklistTile(
            icon: _activityIcons[activity] ?? Icons.circle_outlined,
            label: _activityLabel(activity),
            checked: _activities.contains(activity),
            onChanged: (checked) => setState(() {
              if (checked) {
                _activities.add(activity);
              } else {
                _activities.remove(activity);
              }
            }),
          ),
        const SizedBox(height: SetuSpacing.md),
        const Text('Observed mood', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: SetuSpacing.sm),
        Wrap(
          spacing: SetuSpacing.sm,
          children: [
            for (final mood in VisitToolsRepository.availableMoods)
              ChoiceChip(
                label: Text(mood[0].toUpperCase() + mood.substring(1)),
                selected: _mood == mood,
                onSelected: (selected) =>
                    setState(() => _mood = selected ? mood : null),
                showCheckmark: false,
                selectedColor: SetuColors.lavenderLight,
                labelStyle: TextStyle(
                    color: _mood == mood ? Colors.white : SetuColors.inkLight,
                    fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: SetuSpacing.md),
        TextField(
          controller: _noteController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Short note (optional)',
          ),
        ),
        const SizedBox(height: SetuSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveActivityLog,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(_saving ? 'Saving…' : 'Save Visit Log'),
          ),
        ),
      ],
    );
  }
}

/// A single checklist row — icon, label, and a checkbox — the building
/// block behind the real activity checklist above.
class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.icon,
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!checked),
        child: Container(
          padding: const EdgeInsets.all(SetuSpacing.md),
          decoration: BoxDecoration(
            color: checked
                ? SetuColors.verifiedLight.withValues(alpha: 0.08)
                : SetuColors.paperRaisedLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: checked
                    ? SetuColors.verifiedLight.withValues(alpha: 0.4)
                    : SetuColors.borderLight),
          ),
          child: Row(
            children: [
              SetuIconChip(
                  icon: icon,
                  color: checked ? SetuColors.verifiedLight : SetuColors.accentLight,
                  size: 18),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration:
                            checked ? TextDecoration.lineThrough : null,
                        color: checked ? SetuColors.mutedLight : null)),
              ),
              Checkbox(value: checked, onChanged: (v) => onChanged(v ?? false)),
            ],
          ),
        ),
      ),
    );
  }
}
