import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/booking_repository.dart';

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

  Future<void> _confirm(String regionId) async {
    if (_selected == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo.createBooking(
        elderId: widget.elderId,
        serviceId: _selected!.id,
        scheduledAt: DateTime.now().add(const Duration(
            hours:
                2)), // MVP: "as soon as possible" slot picker is a Phase 2 refinement
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Booking requested')));
        setState(() => _selected = null);
      }
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _submitting = false);
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
                    child: RadioGroup<SetuService>(
                      groupValue: _selected,
                      onChanged: (value) => setState(() => _selected = value),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(SetuSpacing.lg),
                        itemCount: services.length,
                        itemBuilder: (context, index) {
                          final service = services[index];
                          return RadioListTile<SetuService>(
                            value: service,
                            title: Text(service.name),
                            subtitle: Text(
                                '${service.currency} ${service.basePrice.toStringAsFixed(0)}'),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: SetuSpacing.lg),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(SetuSpacing.lg),
                    child: FilledButton(
                      onPressed: (_selected == null || _submitting)
                          ? null
                          : () => _confirm(regionId),
                      child: Text(_submitting ? 'Booking…' : 'Confirm booking'),
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
