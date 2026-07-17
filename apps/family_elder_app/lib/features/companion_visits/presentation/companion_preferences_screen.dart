import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/companion_visits_repository.dart';

/// Companion Visits preferences (PRD Part 6, Batch 3, Module 10): a
/// preferred caregiver (chosen from those who have actually completed a
/// visit with this elder) and a structured interest list — not freeform,
/// so matching and the future recommendation engine can reason over it
/// without NLP.
class CompanionPreferencesScreen extends ConsumerStatefulWidget {
  const CompanionPreferencesScreen({required this.elderId, super.key});

  final String elderId;

  @override
  ConsumerState<CompanionPreferencesScreen> createState() =>
      _CompanionPreferencesScreenState();
}

class _CompanionPreferencesScreenState
    extends ConsumerState<CompanionPreferencesScreen> {
  String? _preferredCaregiverId;
  Set<String> _interests = {};
  List<Map<String, dynamic>> _pastCaregivers = [];
  bool _loaded = false;
  bool _saving = false;

  CompanionVisitsRepository get _repo =>
      CompanionVisitsRepository(ref.read(supabaseClientProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pref = await _repo.fetchPreference(widget.elderId);
    final past = await _repo.fetchPastCaregivers(widget.elderId);
    if (!mounted) return;
    setState(() {
      _preferredCaregiverId = pref?['preferred_caregiver_id'] as String?;
      _interests =
          ((pref?['interests'] as List?)?.cast<String>() ?? []).toSet();
      _pastCaregivers = past;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.savePreference(
        elderId: widget.elderId,
        preferredCaregiverId: _preferredCaregiverId,
        interests: _interests.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Preferences saved')));
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
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Companion preferences')),
        body: const SetuLoading(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Companion preferences')),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          Text('Preferred companion',
              style: Theme.of(context).textTheme.titleMedium),
          const Padding(
            padding: EdgeInsets.only(top: SetuSpacing.xs, bottom: SetuSpacing.sm),
            child: Text(
                'When available and eligible, this caregiver is matched first for companion visits. Safety checks always apply either way.'),
          ),
          if (_pastCaregivers.isEmpty)
            const Text('No completed visits yet — a preferred companion can be chosen after the first visit.',
                style: TextStyle(fontStyle: FontStyle.italic))
          else
            RadioGroup<String?>(
              groupValue: _preferredCaregiverId,
              onChanged: (v) => setState(() => _preferredCaregiverId = v),
              child: Column(
                children: [
                  const RadioListTile<String?>(
                    value: null,
                    title: Text('No preference'),
                  ),
                  for (final cg in _pastCaregivers)
                    RadioListTile<String?>(
                      value: cg['caregiver_id'] as String,
                      title: Text(((cg['caregivers'] as Map<String, dynamic>?)?['profiles']
                              as Map<String, dynamic>?)?['display_name'] as String? ??
                          'Caregiver'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: SetuSpacing.xl),
          Text('Interests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SetuSpacing.sm),
          Wrap(
            spacing: SetuSpacing.sm,
            runSpacing: SetuSpacing.xs,
            children: [
              for (final interest in CompanionVisitsRepository.availableInterests)
                FilterChip(
                  label: Text(interest.replaceAll('_', ' ')),
                  selected: _interests.contains(interest),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _interests.add(interest);
                    } else {
                      _interests.remove(interest);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: SetuSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
