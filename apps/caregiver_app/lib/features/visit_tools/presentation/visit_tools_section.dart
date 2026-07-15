import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/visit_tools_repository.dart';

/// Batch 3 caregiver tools, embedded below the OTP controls on the visit
/// screen. Everything here is visibility-gated by RLS server-side: the
/// emergency health card only comes back during an in-progress booking
/// (or dispatched SOS), and the handoff section only exists when this
/// booking is a shift of a hospital stay.
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

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_healthInfo != null) ...[
          const SizedBox(height: SetuSpacing.lg),
          Card(
            color: SetuColors.sosLight.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(SetuSpacing.md),
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
          ),
        ],
        if (_stayLink != null) ...[
          const SizedBox(height: SetuSpacing.lg),
          Text(
              'Hospital stay — ${(_stayLink!['hospital_stays'] as Map<String, dynamic>?)?['hospital_name'] ?? ''}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SetuSpacing.sm),
          for (final note in _stayNotes)
            if (note['booking_id'] != widget.bookingId)
              Padding(
                padding: const EdgeInsets.only(bottom: SetuSpacing.xs),
                child: Text('Previous shift: ${note['shift_note']}'),
              ),
          TextField(
            controller: _handoffController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Handoff note for the next shift',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SetuSpacing.sm),
          OutlinedButton(
            onPressed: _saving ? null : _saveHandoff,
            child: const Text('Save handoff note'),
          ),
        ],
        const SizedBox(height: SetuSpacing.lg),
        Text('Visit activity log', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: SetuSpacing.sm),
        Wrap(
          spacing: SetuSpacing.sm,
          runSpacing: SetuSpacing.xs,
          children: [
            for (final activity in VisitToolsRepository.availableActivities)
              FilterChip(
                label: Text(activity.replaceAll('_', ' ')),
                selected: _activities.contains(activity),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _activities.add(activity);
                  } else {
                    _activities.remove(activity);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: SetuSpacing.sm),
        Wrap(
          spacing: SetuSpacing.sm,
          children: [
            for (final mood in VisitToolsRepository.availableMoods)
              ChoiceChip(
                label: Text(mood),
                selected: _mood == mood,
                onSelected: (selected) =>
                    setState(() => _mood = selected ? mood : null),
              ),
          ],
        ),
        const SizedBox(height: SetuSpacing.sm),
        TextField(
          controller: _noteController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Short note (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: SetuSpacing.sm),
        FilledButton(
          onPressed: _saving ? null : _saveActivityLog,
          child: Text(_saving ? 'Saving…' : 'Save activity log'),
        ),
      ],
    );
  }
}
