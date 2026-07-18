import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/booking_repository.dart';

String _roleLabel(String subRole) {
  switch (subRole) {
    case 'nurse':
      return 'Home-care nurse';
    case 'physiotherapist':
      return 'Physiotherapist';
    case 'hospital_attendant':
      return 'Hospital attendant';
    case 'companion':
      return 'Companion';
    case 'home_service_maid':
      return 'Home helper';
    case 'home_service_electrician':
      return 'Electrician';
    case 'home_service_plumber':
      return 'Plumber';
    default:
      return 'Caregiver';
  }
}

({String label, Color color}) _trust(String tier) {
  switch (tier) {
    case 'clinical_verified':
      return (label: 'Clinically verified', color: SetuColors.verifiedLight);
    case 'standard':
      return (label: 'Verified', color: SetuColors.accentLight);
    default:
      return (label: 'New joiner', color: SetuColors.peachLight);
  }
}

/// Choose-your-caregiver (the family's own words: "select the caregiver's
/// profile based on their details so it's helpful to choose the best one").
/// Lists verified caregivers for the chosen service — name, role, trust tier,
/// rating and bio — plus an explicit "let CareHive match" option for families
/// who'd rather not pick. Requesting a specific caregiver books them directly.
class CaregiverSelectScreen extends ConsumerStatefulWidget {
  const CaregiverSelectScreen({
    required this.elderId,
    required this.service,
    required this.scheduledAt,
    super.key,
  });

  final String elderId;
  final SetuService service;
  final DateTime scheduledAt;

  @override
  ConsumerState<CaregiverSelectScreen> createState() =>
      _CaregiverSelectScreenState();
}

class _CaregiverSelectScreenState extends ConsumerState<CaregiverSelectScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _submitting = false;

  BookingRepository get _repo =>
      BookingRepository(ref.read(supabaseClientProvider));

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchCaregiversForService(
      elderId: widget.elderId,
      serviceId: widget.service.id,
    );
  }

  Future<void> _book({String? caregiverId, String? caregiverName}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _repo.createBooking(
        elderId: widget.elderId,
        serviceId: widget.service.id,
        scheduledAt: widget.scheduledAt,
        caregiverId: caregiverId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(caregiverName == null
            ? 'Requested — we\'ll match the best caregiver for ${widget.service.name}.'
            : 'Requested $caregiverName for ${widget.service.name}.'),
      ));
    } catch (err) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not request: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a caregiver')),
      body: Stack(
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SetuLoading(label: 'Finding caregivers near you…');
              }
              final caregivers = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(SetuSpacing.lg),
                children: [
                  Text('For ${widget.service.name}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.event_outlined,
                          size: 16, color: SetuColors.accentLight),
                      const SizedBox(width: 6),
                      Text(
                          '${SetuFormat.friendlyDate(widget.scheduledAt)} · '
                          '${TimeOfDay.fromDateTime(widget.scheduledAt).format(context)}',
                          style: const TextStyle(
                              color: SetuColors.accentLight,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: SetuSpacing.sm),
                  const Text(
                    'Pick someone you trust from their profile below, or let '
                    'CareHive match the best available.',
                    style: TextStyle(color: SetuColors.mutedLight),
                  ),
                  const SizedBox(height: SetuSpacing.md),
                  _AutoMatchCard(onTap: () => _book()),
                  const SizedBox(height: SetuSpacing.lg),
                  if (caregivers.isEmpty)
                    const _NoCaregivers()
                  else ...[
                    Text('${caregivers.length} available',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: SetuSpacing.sm),
                    for (final c in caregivers)
                      _CaregiverCard(
                        caregiver: c,
                        onRequest: () => _book(
                            caregiverId: c['id'] as String,
                            caregiverName: c['name'] as String?),
                      ),
                  ],
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
          if (_submitting)
            const ColoredBox(
              color: Color(0x66000000),
              child: SetuLoading(label: 'Requesting…'),
            ),
        ],
      ),
    );
  }
}

class _AutoMatchCard extends StatelessWidget {
  const _AutoMatchCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [
            SetuColors.accentLight.withValues(alpha: 0.16),
            SetuColors.accentLight.withValues(alpha: 0.05),
          ]),
          border:
              Border.all(color: SetuColors.accentLight.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const SetuIconChip(icon: Icons.auto_awesome, size: 22),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Let CareHive match the best',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  const Text('Fastest — we pick a top-rated, available caregiver.',
                      style: TextStyle(
                          fontSize: 12.5, color: SetuColors.mutedLight)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: SetuColors.accentLight),
          ],
        ),
      ),
    );
  }
}

class _NoCaregivers extends StatelessWidget {
  const _NoCaregivers();
  @override
  Widget build(BuildContext context) {
    return const SetuEmptyState(
      icon: Icons.groups_outlined,
      title: 'No profiles to show yet',
      message:
          'No caregivers are listed for this service in your area right now. '
          'Tap "Let CareHive match the best" above and our team will find one.',
    );
  }
}

class _CaregiverCard extends StatelessWidget {
  const _CaregiverCard({required this.caregiver, required this.onRequest});

  final Map<String, dynamic> caregiver;
  final VoidCallback onRequest;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = caregiver['name'] as String? ?? 'CareHive caregiver';
    final subRole = caregiver['sub_role'] as String? ?? '';
    final tier = _trust(caregiver['trust_tier'] as String? ?? '');
    final photoUrl = caregiver['photo_url'] as String?;
    final stars = (caregiver['average_stars'] as num?)?.toDouble() ?? 0;
    final count = (caregiver['rating_count'] as num?)?.toInt() ?? 0;
    final bio = caregiver['bio'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: SetuSpacing.md),
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: SetuColors.accentLight.withValues(alpha: 0.15),
                backgroundImage:
                    (photoUrl != null) ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(_initials(name),
                        style: const TextStyle(
                            color: SetuColors.accentLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 18))
                    : null,
              ),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(_roleLabel(subRole),
                        style: const TextStyle(color: SetuColors.mutedLight)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: SetuSpacing.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SetuStatusPill(label: tier.label, color: tier.color),
                        if (count > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 16, color: SetuColors.peachLight),
                              const SizedBox(width: 2),
                              Text(stars.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(' ($count)',
                                  style: const TextStyle(
                                      color: SetuColors.mutedLight,
                                      fontSize: 12.5)),
                            ],
                          )
                        else
                          const Text('New to CareHive',
                              style: TextStyle(
                                  color: SetuColors.mutedLight, fontSize: 12.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: SetuSpacing.sm),
            Text(bio,
                style: const TextStyle(height: 1.4, color: SetuColors.inkLight)),
          ],
          const SizedBox(height: SetuSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: Text('Request ${name.split(' ').first}'),
            ),
          ),
        ],
      ),
    );
  }
}
