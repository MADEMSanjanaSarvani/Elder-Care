import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/booking_repository.dart';

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
  bool _submitting = false;
  String? _error;

  BookingRepository get _repo =>
      BookingRepository(ref.read(supabaseClientProvider));

  Future<void> _confirm() async {
    if (_selected == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo.createBooking(
        elderId: widget.elderId,
        serviceId: _selected!.id,
        // MVP: "as soon as possible" — a slot picker is a Phase 2 refinement.
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Help requested — we\'ll match a caregiver.')),
        );
        setState(() => _selected = null);
      }
    } catch (err) {
      setState(() => _error = 'Could not book: $err');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                return const Center(child: CircularProgressIndicator());
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
                          'Pick a service — we\'ll match a verified caregiver near you.',
                          style: TextStyle(color: SetuColors.mutedLight),
                        ),
                        const SizedBox(height: SetuSpacing.md),
                        for (final service in services)
                          _ServiceCard(
                            service: service,
                            selected: _selected?.id == service.id,
                            onTap: () => setState(() => _selected = service),
                          ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: SetuSpacing.lg),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(SetuSpacing.lg),
                      child: FilledButton(
                        onPressed: (_selected == null || _submitting)
                            ? null
                            : _confirm,
                        child: Text(_submitting
                            ? 'Requesting…'
                            : _selected == null
                                ? 'Choose a service'
                                : 'Request ${_selected!.name}'),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Something went wrong: $err')),
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
                    const SizedBox(height: 2),
                    Text(
                      'From ${service.currency} ${service.basePrice.toStringAsFixed(0)}',
                      style: const TextStyle(color: SetuColors.mutedLight),
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
