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
    final name = (ref.watch(currentProfileProvider).asData?.value?[
            'display_name'] as String?)
        ?.trim();
    final initials = (name == null || name.isEmpty)
        ? '★'
        : name
            .split(' ')
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0].toUpperCase())
            .join();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          // Stitch caregiver_details header: warm mesh, avatar, verified badge
          // and the aggregate rating.
          Container(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFFFFDBC9), Color(0xFFE7DEFF)],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SetuColors.paperRaisedLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Text(initials,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: SetuColors.accentLight)),
                ),
                const SizedBox(height: SetuSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name == null || name.isEmpty ? 'Your profile' : name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified,
                        color: SetuColors.lavenderLight, size: 20),
                  ],
                ),
                const SizedBox(height: SetuSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: SetuColors.peachLight, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      avg != null && count > 0
                          ? '${avg.toStringAsFixed(1)} · $count ${count == 1 ? 'review' : 'reviews'}'
                          : 'New caregiver',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.lg),
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
