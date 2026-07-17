import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/caregiver_profile_repository.dart';

/// Caregiver profile + performance (PRD Part 8, Batch 5, Modules 17 & 18).
/// Self-service bio and service radius on top; an aggregate rating and the
/// anonymized reviews below — the caregiver sees the feedback but never
/// the author, by design.
class CaregiverProfileScreen extends ConsumerStatefulWidget {
  const CaregiverProfileScreen({required this.caregiverId, super.key});

  final String caregiverId;

  @override
  ConsumerState<CaregiverProfileScreen> createState() =>
      _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends ConsumerState<CaregiverProfileScreen> {
  final _bioController = TextEditingController();
  final _radiusController = TextEditingController();
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _reviews = [];
  bool _loaded = false;
  bool _saving = false;

  CaregiverProfileRepository get _repo =>
      CaregiverProfileRepository(ref.read(supabaseClientProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _repo.fetchProfile(widget.caregiverId);
    final summary = await _repo.fetchRatingSummary(widget.caregiverId);
    final reviews = await _repo.fetchAnonymizedReviews(widget.caregiverId);
    if (!mounted) return;
    setState(() {
      _bioController.text = profile?['bio'] as String? ?? '';
      _radiusController.text =
          (profile?['service_radius_km'] as num?)?.toString() ?? '';
      _summary = summary;
      _reviews = reviews;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.saveProfile(
        caregiverId: widget.caregiverId,
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        serviceRadiusKm: double.tryParse(_radiusController.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved')));
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
        appBar: AppBar(title: const Text('Profile')),
        body: const SetuLoading(),
      );
    }
    final avg = (_summary?['average_stars'] as num?)?.toDouble();
    final count = _summary?['rating_count'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          if (avg != null && count > 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SetuSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: SetuColors.accentLight),
                    const SizedBox(width: SetuSpacing.sm),
                    Text('${avg.toStringAsFixed(2)} average',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: SetuSpacing.sm),
                    Text('($count ${count == 1 ? 'review' : 'reviews'})',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          const SizedBox(height: SetuSpacing.md),
          Text('About you', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Short bio (shown to families)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: _radiusController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Service radius (km)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SetuSpacing.md),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save profile'),
          ),
          const SizedBox(height: SetuSpacing.xl),
          Text('Recent feedback', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SetuSpacing.sm),
          if (_reviews.isEmpty)
            const Text('No reviews yet.', style: TextStyle(fontStyle: FontStyle.italic))
          else
            for (final review in _reviews)
              Card(
                child: ListTile(
                  leading: Text('${review['stars']}★'),
                  title: Text(review['review_text'] as String? ?? 'No comment left'),
                ),
              ),
        ],
      ),
    );
  }
}
