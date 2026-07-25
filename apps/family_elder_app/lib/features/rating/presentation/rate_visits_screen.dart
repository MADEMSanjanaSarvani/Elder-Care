import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/rating_repository.dart';
import '../../../core/illustrations.dart';

final _unratedProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return RatingRepository(client).unratedCompletedBookings(elderId);
});

/// Post-visit rating (PRD Part 8, Batch 5, Module 18). Lists completed
/// visits not yet rated, each with a quick 1–5 star + optional review
/// prompt. One rating per booking is enforced by the database; this
/// screen just won't show an already-rated visit again.
class RateVisitsScreen extends ConsumerWidget {
  const RateVisitsScreen({required this.elderId, super.key});

  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unratedAsync = ref.watch(_unratedProvider(elderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Rate a visit')),
      body: unratedAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return SetuEmptyState(
              artwork: SetuArt.emptyCare(),
              icon: Icons.star_outline,
              title: 'Nothing to rate',
              message: 'After a completed visit, you can rate it here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: bookings.length,
            separatorBuilder: (context, index) => const SizedBox(height: SetuSpacing.sm),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final service =
                  (booking['service_catalog'] as Map<String, dynamic>?)?['name'] as String? ?? 'Visit';
              final at = DateTime.parse(booking['scheduled_at'] as String).toLocal();
              return Card(
                child: ListTile(
                  leading: const SetuIconChip(
                      icon: Icons.volunteer_activism_outlined),
                  title: Text(service),
                  subtitle: Text(SetuFormat.friendlyDate(at)),
                  trailing: const Icon(Icons.star_outline),
                  onTap: () => _showRatingDialog(context, ref, booking),
                ),
              );
            },
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }

  Future<void> _showRatingDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> booking) async {
    int stars = 5;
    final reviewController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('How was the visit?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(i <= stars ? Icons.star : Icons.star_border,
                          color: SetuColors.accentLight),
                      onPressed: () => setState(() => stars = i),
                    ),
                ],
              ),
              TextField(
                controller: reviewController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'A few words (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Submit')),
          ],
        ),
      ),
    );

    if (submitted != true) return;
    try {
      await RatingRepository(ref.read(supabaseClientProvider)).submitRating(
        bookingId: booking['id'] as String,
        caregiverId: booking['caregiver_id'] as String,
        stars: stars,
        reviewText: reviewController.text.trim(),
      );
      ref.invalidate(_unratedProvider(elderId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Thanks for your feedback')));
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not submit: $err')));
      }
    }
  }
}
