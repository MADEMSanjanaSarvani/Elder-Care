import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/booking_repository.dart';
import 'caregiver_select_screen.dart';

/// One plain line describing what actually happens on the visit.
///
/// The catalogue only stores a name and a price, and "Home Nursing Visit —
/// from ₹1199" tells a worried daughter nothing about what she's buying.
/// These live here rather than in the database on purpose: they're product
/// copy, they change with the wording of the app, and adding a column would
/// mean a migration and a redeploy every time a sentence is reworded.
String _serviceBlurb(String code) {
  switch (code) {
    case 'companionship_visit':
      return 'Someone sits with them, talks, and shares a cup of tea.';
    case 'medicine_pickup':
      return 'We collect the prescription and deliver it to their door.';
    case 'grocery_assistance':
      return 'Shopping done and put away, from their own list.';
    case 'physiotherapy':
      return 'A trained physio runs their exercises at home.';
    case 'home_nursing':
      return 'A qualified nurse for dressings, injections and vitals.';
    case 'hospital_companion':
      return 'Accompanied to the appointment, with notes sent to you after.';
    default:
      return 'A verified caregiver visits and helps at home.';
  }
}

IconData _serviceIcon(String code) {
  switch (code) {
    case 'companionship_visit':
      return Icons.diversity_1_outlined;
    case 'medicine_pickup':
      return Icons.medication_outlined;
    case 'grocery_assistance':
      return Icons.shopping_basket_outlined;
    case 'physiotherapy':
      return Icons.self_improvement_outlined;
    case 'home_nursing':
      return Icons.medical_services_outlined;
    case 'hospital_companion':
      return Icons.local_hospital_outlined;
    default:
      return Icons.volunteer_activism_outlined;
  }
}

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({required this.elderId, super.key});

  final String elderId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  SetuService? _selected;
  late DateTime _when = _defaultSlot();

  BookingRepository get _repo =>
      BookingRepository(ref.read(supabaseClientProvider));

  /// A sensible first suggestion: the next morning at 10:00.
  static DateTime _defaultSlot() {
    final t = DateTime.now().add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day, 10);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _when =
          DateTime(picked.year, picked.month, picked.day, _when.hour, _when.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (picked != null) {
      setState(() => _when = DateTime(
          _when.year, _when.month, _when.day, picked.hour, picked.minute));
    }
  }

  void _chooseCaregiver() {
    if (_selected == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CaregiverSelectScreen(
        elderId: widget.elderId,
        service: _selected!,
        scheduledAt: _when,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final elderAsync = ref.watch(elderProfileByIdProvider(widget.elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Book help')),
      body: elderAsync.when(
        data: (elder) {
          if (elder == null) {
            return const Center(child: Text('Elder not found'));
          }
          final regionId = elder['region_id'] as String;
          return FutureBuilder<List<SetuService>>(
            future: _repo.fetchServices(regionId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SetuLoading();
              }
              final services = snapshot.data!;
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(SetuSpacing.lg),
                      children: [
                        Text('What help do you need?',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: SetuSpacing.xs),
                        const Text(
                          'Pick a service, then choose the caregiver you like best.',
                          style: TextStyle(color: SetuColors.mutedLight),
                        ),
                        const SizedBox(height: SetuSpacing.md),
                        for (final service in services)
                          _ServiceCard(
                            service: service,
                            selected: _selected?.id == service.id,
                            onTap: () => setState(() => _selected = service),
                          ),
                        if (_selected != null) ...[
                          const SizedBox(height: SetuSpacing.lg),
                          Text('When do you need help?',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: SetuSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: _WhenTile(
                                  icon: Icons.calendar_today_outlined,
                                  label: SetuFormat.friendlyDate(_when),
                                  onTap: _pickDate,
                                ),
                              ),
                              const SizedBox(width: SetuSpacing.sm),
                              Expanded(
                                child: _WhenTile(
                                  icon: Icons.access_time,
                                  label: TimeOfDay.fromDateTime(_when)
                                      .format(context),
                                  onTap: _pickTime,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(SetuSpacing.lg),
                      child: FilledButton.icon(
                        onPressed: _selected == null ? null : _chooseCaregiver,
                        icon: const Icon(Icons.groups_outlined),
                        label: Text(_selected == null
                            ? 'Choose a service'
                            : 'See caregivers for ${_selected!.name}'),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) =>
            const SetuErrorState(),
      ),
    );
  }
}

class _WhenTile extends StatelessWidget {
  const _WhenTile(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: SetuSpacing.md, horizontal: SetuSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SetuColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: SetuColors.accentLight),
            const SizedBox(width: SetuSpacing.sm),
            Expanded(
              child: Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.edit_outlined,
                size: 15, color: SetuColors.mutedLight),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard(
      {required this.service, required this.selected, required this.onTap});

  final SetuService service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = SetuColors.accentLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(SetuSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? accent.withValues(alpha: 0.06) : null,
            border: Border.all(
              color: selected ? accent : SetuColors.borderLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(SetuSpacing.sm),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_serviceIcon(service.code), color: accent),
              ),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      _serviceBlurb(service.code),
                      style: const TextStyle(
                          color: SetuColors.mutedLight,
                          fontSize: 13.5,
                          height: 1.35),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'From ${formatMoney(service.basePrice, currency: service.currency)}',
                      style: const TextStyle(
                          color: SetuColors.accentLight,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: selected ? accent : SetuColors.borderLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
