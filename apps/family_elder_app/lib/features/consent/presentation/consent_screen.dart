import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/consent_repository.dart';

final _familyLinksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('family_links')
      .select()
      .eq('elder_id', elderId)
      .eq('status', 'active');
});

/// Consent management (PRD Part 1 §04): the elder grants access per
/// category, per family member, and can revoke at any time. A family
/// member only ever sees a read-only view of what they currently have —
/// this screen never lets anyone but the elder flip these switches, and
/// the RLS policy on `consent_grants` enforces that independently of what
/// this UI shows.
class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elderAsync = ref.watch(elderProfileByIdProvider(elderId));
    final currentUserId =
        ref.watch(supabaseClientProvider).auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('What you can see')),
      body: elderAsync.when(
        data: (elder) {
          if (elder == null) {
            return const Center(child: Text('Elder not found'));
          }
          final isElderSelf = elder['auth_user_id'] == currentUserId;

          if (isElderSelf) {
            return _FamilyMemberConsentEditor(elderId: elderId);
          }
          return _ReadOnlyConsentView(
            elderId: elderId,
            elderName: elder['display_name'] as String,
            familyUserId: currentUserId!,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Something went wrong: $err')),
      ),
    );
  }
}

class _ReadOnlyConsentView extends ConsumerWidget {
  const _ReadOnlyConsentView(
      {required this.elderId,
      required this.elderName,
      required this.familyUserId});

  final String elderId;
  final String elderName;
  final String familyUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ConsentRepository(ref.watch(supabaseClientProvider));
    return FutureBuilder<List<ConsentGrant>>(
      future: repo.fetchGrants(elderId: elderId, familyUserId: familyUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final gate = ConsentGate(snapshot.data!);
        return ListView(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          children: [
            Text('Only $elderName can change this',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: SetuSpacing.md),
            for (final category in ConsentCategory.values)
              CheckboxListTile(
                value: gate.canView(category),
                onChanged: null, // read-only: enforced server-side regardless
                title: Text(_categoryLabel(category)),
              ),
          ],
        );
      },
    );
  }
}

class _FamilyMemberConsentEditor extends ConsumerWidget {
  const _FamilyMemberConsentEditor({required this.elderId});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyLinksAsync = ref.watch(_familyLinksProvider(elderId));
    return familyLinksAsync.when(
      data: (links) {
        if (links.isEmpty) {
          return const Center(child: Text('No linked family members yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          itemCount: links.length,
          itemBuilder: (context, index) {
            final familyUserId = links[index]['family_user_id'] as String;
            return _FamilyMemberConsentCard(
                elderId: elderId, familyUserId: familyUserId);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Something went wrong: $err')),
    );
  }
}

class _FamilyMemberConsentCard extends ConsumerStatefulWidget {
  const _FamilyMemberConsentCard(
      {required this.elderId, required this.familyUserId});

  final String elderId;
  final String familyUserId;

  @override
  ConsumerState<_FamilyMemberConsentCard> createState() =>
      _FamilyMemberConsentCardState();
}

class _FamilyMemberConsentCardState
    extends ConsumerState<_FamilyMemberConsentCard> {
  late Future<List<ConsentGrant>> _grantsFuture;

  ConsentRepository get _repo =>
      ConsentRepository(ref.read(supabaseClientProvider));

  @override
  void initState() {
    super.initState();
    _grantsFuture = _repo.fetchGrants(
        elderId: widget.elderId, familyUserId: widget.familyUserId);
  }

  Future<void> _toggle(ConsentCategory category, bool value) async {
    await _repo.setGrant(
      elderId: widget.elderId,
      familyUserId: widget.familyUserId,
      category: category,
      granted: value,
    );
    setState(() {
      _grantsFuture = _repo.fetchGrants(
          elderId: widget.elderId, familyUserId: widget.familyUserId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: FutureBuilder<List<ConsentGrant>>(
        future: _grantsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(SetuSpacing.md),
              child: LinearProgressIndicator(),
            );
          }
          final gate = ConsentGate(snapshot.data!);
          return Column(
            children: [
              for (final category in ConsentCategory.values)
                CheckboxListTile(
                  value: gate.canView(category),
                  onChanged: (value) => _toggle(category, value ?? false),
                  title: Text(_categoryLabel(category)),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _categoryLabel(ConsentCategory category) {
  switch (category) {
    case ConsentCategory.locationLive:
      return 'Live location';
    case ConsentCategory.locationHistory:
      return 'Location history';
    case ConsentCategory.healthNotes:
      return 'Health notes';
    case ConsentCategory.medicationList:
      return 'Medication list';
    case ConsentCategory.visitHistory:
      return 'Full visit history';
    case ConsentCategory.billing:
      return 'Billing details';
  }
}
