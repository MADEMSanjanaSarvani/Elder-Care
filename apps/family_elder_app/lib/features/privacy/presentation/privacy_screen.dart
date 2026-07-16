import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/privacy_repository.dart';

final _accessHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return PrivacyRepository(client).fetchAccessHistory(elderId);
});

final _guardianRequestsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return PrivacyRepository(client).fetchGuardianRequests(elderId);
});

/// Privacy Center (PRD Part 10, Batch 7, Module 24). This screen does NOT
/// introduce a new access model — it surfaces three existing things in one
/// place: who has looked at this elder's data (from the me-access-history
/// function's audit read), the standing guardian-consent requests, and a
/// form to file a new one. The actual grant still happens through the admin
/// review + existing consent_grants path; filing a request grants nothing.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_accessHistoryProvider(elderId));
    final requestsAsync = ref.watch(_guardianRequestsProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy centre')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_accessHistoryProvider(elderId));
          ref.invalidate(_guardianRequestsProvider(elderId));
          await ref.read(_accessHistoryProvider(elderId).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          children: [
            const _SectionHeader(
              icon: Icons.visibility_outlined,
              title: 'Who has seen this data',
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: SetuSpacing.sm),
              child: Text(
                'Every time someone opens sensitive information, it is logged '
                'here. This is a record, not a setting.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            historyAsync.when(
              data: (entries) => entries.isEmpty
                  ? const _EmptyNote('No access recorded yet.')
                  : Column(
                      children: [
                        for (final e in entries) _AccessTile(entry: e),
                      ],
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(SetuSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => _EmptyNote('Could not load history: $err'),
            ),
            const SizedBox(height: SetuSpacing.lg),
            const _SectionHeader(
              icon: Icons.assignment_ind_outlined,
              title: 'Guardian access requests',
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: SetuSpacing.sm),
              child: Text(
                'When an elder cannot grant access themselves, a family member '
                'can request it on a documented basis. An administrator reviews '
                'every request — filing one does not grant anything.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            requestsAsync.when(
              data: (requests) => Column(
                children: [
                  for (final r in requests) _RequestTile(request: r),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(SetuSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => _EmptyNote('Could not load requests: $err'),
            ),
            const SizedBox(height: SetuSpacing.sm),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Request guardian access'),
              onPressed: () => _openRequestForm(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRequestForm(BuildContext context, WidgetRef ref) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GuardianRequestForm(elderId: elderId),
    );
    if (submitted == true) {
      ref.invalidate(_guardianRequestsProvider(elderId));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: SetuSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SetuSpacing.md),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _AccessTile extends StatelessWidget {
  const _AccessTile({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    // me-access-history returns { when, action, resource, detail }.
    final action = entry['action'] as String? ?? 'accessed';
    final resource = entry['resource'] as String?;
    final at = entry['when'] as String?;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.remove_red_eye_outlined, size: 18),
      title: Text(_humanAction(action)),
      subtitle: Text([
        if (resource != null) resource.replaceAll('_', ' '),
        if (at != null) _humanDate(at),
      ].join(' • ')),
    );
  }
}

String _humanAction(String action) {
  final spaced = action.replaceAll('_', ' ');
  return spaced.isEmpty ? spaced : spaced[0].toUpperCase() + spaced.substring(1);
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final category = request['category'] as String? ?? '';
    final status = request['status'] as String? ?? 'pending';
    final basis = request['basis_description'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: SetuSpacing.sm),
      child: ListTile(
        title: Text(_humanCategory(category)),
        subtitle: Text(basis),
        trailing: _StatusChip(status: status),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'approved' => (SetuColors.verifiedLight, 'Approved'),
      'denied' => (SetuColors.sosLight, 'Denied'),
      _ => (Theme.of(context).colorScheme.outline, 'Pending'),
    };
    return Chip(
      label: Text(label),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.10),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// The request form. Category is limited to the existing consent_category
/// enum values — a guardian request can only ask for access the consent
/// model already understands. A documented basis is mandatory (PRD Part 2
/// §13); the field cannot be left blank.
class _GuardianRequestForm extends ConsumerStatefulWidget {
  const _GuardianRequestForm({required this.elderId});

  final String elderId;

  @override
  ConsumerState<_GuardianRequestForm> createState() =>
      _GuardianRequestFormState();
}

class _GuardianRequestFormState extends ConsumerState<_GuardianRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _basisController = TextEditingController();
  ConsentCategory _category = ConsentCategory.values.first;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _basisController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await PrivacyRepository(ref.read(supabaseClientProvider))
          .submitGuardianRequest(
        elderId: widget.elderId,
        category: _category.wireValue,
        basisDescription: _basisController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: SetuSpacing.lg,
        right: SetuSpacing.lg,
        top: SetuSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + SetuSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request guardian access',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SetuSpacing.md),
            DropdownButtonFormField<ConsentCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in ConsentCategory.values)
                  DropdownMenuItem(value: c, child: Text(_humanCategory(c.wireValue))),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: SetuSpacing.md),
            TextFormField(
              controller: _basisController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Documented basis',
                hintText:
                    'e.g. Power of attorney dated 12 Jan 2026; elder unable to consent.',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'A documented basis is required'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: SetuSpacing.sm),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: SetuSpacing.lg),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Submitting…' : 'Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}

String _humanCategory(String wire) {
  switch (wire) {
    case 'location_live':
      return 'Live location';
    case 'location_history':
      return 'Location history';
    case 'health_notes':
      return 'Health notes';
    case 'medication_list':
      return 'Medication list';
    case 'visit_history':
      return 'Full visit history';
    case 'billing':
      return 'Billing details';
    case 'wellbeing_checkins':
      return 'Daily check-ins';
    default:
      return wire.replaceAll('_', ' ');
  }
}

String _humanDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
