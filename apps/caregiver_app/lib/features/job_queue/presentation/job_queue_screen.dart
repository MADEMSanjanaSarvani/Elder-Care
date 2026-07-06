import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import 'pending_verification_screen.dart';

/// A job list first, everything else second (PRD Part 3 §17) — this is
/// the caregiver's home screen, not a tab buried under something else.
class JobQueueScreen extends ConsumerWidget {
  const JobQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caregiverAsync = ref.watch(myCaregiverProvider);

    return caregiverAsync.when(
      data: (caregiver) {
        if (caregiver == null) return const PendingVerificationScreen();
        return _JobList(caregiver: caregiver);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Something went wrong: $err'))),
    );
  }
}

class _JobList extends ConsumerWidget {
  const _JobList({required this.caregiver});

  final Caregiver caregiver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myBookingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push('/earnings'),
          ),
        ],
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) return const Center(child: Text('No jobs assigned right now.'));
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: bookings.length,
            separatorBuilder: (context, index) => const SizedBox(height: SetuSpacing.sm),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Card(
                child: ListTile(
                  title: Text(_statusLabel(booking.status)),
                  subtitle: Text(booking.scheduledAt.toLocal().toString()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/booking/${booking.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Something went wrong: $err')),
      ),
    );
  }
}

String _statusLabel(BookingStatus status) {
  switch (status) {
    case BookingStatus.matched:
      return 'Assigned — ready to start';
    case BookingStatus.confirmed:
      return 'Confirmed';
    case BookingStatus.inProgress:
      return 'In progress';
    case BookingStatus.requested:
      return 'Requested';
    case BookingStatus.completed:
      return 'Completed';
    case BookingStatus.cancelled:
      return 'Cancelled';
    case BookingStatus.disputed:
      return 'Disputed';
  }
}
