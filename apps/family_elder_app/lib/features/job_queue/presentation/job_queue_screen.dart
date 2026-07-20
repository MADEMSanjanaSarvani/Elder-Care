import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../../caregiver_onboarding/presentation/caregiver_registration_screen.dart';
import '../../wellness/presentation/weekly_activity_chart.dart';
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
        // No caregiver record yet -> they haven't applied: show the
        // professional registration form. Applied but not yet activated by an
        // admin -> pending verification. Active -> their job list.
        if (caregiver == null) return const CaregiverRegistrationScreen();
        if (!caregiver.active) return const PendingVerificationScreen();
        return _JobList(caregiver: caregiver);
      },
      loading: () =>
          const Scaffold(body: SetuLoading()),
      error: (err, stack) =>
          const Scaffold(body: SetuErrorState()),
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
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile & ratings',
            onPressed: () => context.push('/profile/${caregiver.id}'),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push('/earnings'),
          ),
        ],
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) return const _NoJobs();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myBookingsProvider);
              await ref.read(myBookingsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(SetuSpacing.lg),
              children: [
                Builder(builder: (context) {
                  final name = (ref.watch(currentProfileProvider).asData?.value?[
                          'display_name'] as String?)
                      ?.trim()
                      .split(' ')
                      .first;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name != null && name.isNotEmpty ? 'Hello, $name.' : 'Hello.',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                          'You have ${bookings.length} visit${bookings.length == 1 ? '' : 's'} today.',
                          style: const TextStyle(color: SetuColors.mutedLight)),
                    ],
                  );
                }),
                const SizedBox(height: SetuSpacing.lg),
                // Bento stat row (Stitch caregiver dashboard): quick glance at
                // today's load, completed visits and a tap-through to earnings.
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.today_outlined,
                        tint: SetuColors.accentLight,
                        value: '${bookings.length}',
                        label: 'Visits today',
                      ),
                    ),
                    const SizedBox(width: SetuSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.task_alt,
                        tint: SetuColors.verifiedLight,
                        value: '${bookings.where((b) => b.status == BookingStatus.completed).length}',
                        label: 'Completed',
                      ),
                    ),
                    const SizedBox(width: SetuSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.account_balance_wallet_outlined,
                        tint: SetuColors.lavenderLight,
                        value: 'View',
                        label: 'Earnings',
                        onTap: () => context.push('/earnings'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SetuSpacing.lg),
                Builder(builder: (context) {
                  final start = DateTime.now()
                      .subtract(const Duration(days: 6));
                  final startDay =
                      DateTime(start.year, start.month, start.day);
                  final counts = List<int>.filled(7, 0);
                  for (final b in bookings) {
                    final d = b.scheduledAt.toLocal();
                    final idx = DateTime(d.year, d.month, d.day)
                        .difference(startDay)
                        .inDays;
                    if (idx >= 0 && idx < 7) counts[idx]++;
                  }
                  return WeeklyBarChart(
                    counts: counts,
                    title: "This week's visits",
                    icon: Icons.event_available_outlined,
                    emptyHint: 'Your visits this week will show here.',
                  );
                }),
                const SizedBox(height: SetuSpacing.lg),
                for (final booking in bookings)
                  _JobCard(booking: booking),
              ],
            ),
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) =>
            const SetuErrorState(),
      ),
    );
  }
}

class _NoJobs extends StatelessWidget {
  const _NoJobs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available_outlined,
                size: 56, color: SetuColors.mutedLight),
            const SizedBox(height: SetuSpacing.md),
            Text('No visits right now',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SetuSpacing.xs),
            const Text('New assignments will show up here.',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SetuColors.paperRaisedLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(SetuSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SetuColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: tint, size: 22),
              const SizedBox(height: SetuSpacing.sm),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tint)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: SetuColors.mutedLight)),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final canStart = booking.status == BookingStatus.matched ||
        booking.status == BookingStatus.confirmed;
    final inProgress = booking.status == BookingStatus.inProgress;
    final color = _statusColor(booking.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(SetuSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: SetuSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_statusLabel(booking.status),
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text(_friendlyTime(booking.scheduledAt.toLocal()),
                      style: const TextStyle(
                          color: SetuColors.mutedLight, fontSize: 13)),
                ],
              ),
              const SizedBox(height: SetuSpacing.md),
              if (canStart) ...[
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/caregiver/trip/${booking.id}'),
                  icon: const Icon(Icons.directions_car_filled_outlined),
                  label: const Text('On my way'),
                ),
                const SizedBox(height: SetuSpacing.sm),
              ],
              if (canStart || inProgress)
                FilledButton.icon(
                  onPressed: () => context.push('/booking/${booking.id}'),
                  icon: Icon(inProgress
                      ? Icons.play_arrow
                      : Icons.login),
                  label: Text(inProgress ? 'Continue visit' : 'Start visit'),
                )
              else
                OutlinedButton(
                  onPressed: () => context.push('/booking/${booking.id}'),
                  child: const Text('View details'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _statusColor(BookingStatus status) {
  switch (status) {
    case BookingStatus.inProgress:
      return SetuColors.verifiedLight;
    case BookingStatus.disputed:
    case BookingStatus.cancelled:
      return SetuColors.sosLight;
    case BookingStatus.completed:
      return SetuColors.verifiedLight;
    default:
      return SetuColors.accentLight;
  }
}

String _friendlyTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final h = dt.hour == 0 || dt.hour == 12 ? 12 : dt.hour % 12;
  final time = '$h:${dt.minute.toString().padLeft(2, '0')} '
      '${dt.hour < 12 ? 'AM' : 'PM'}';
  final days = that.difference(today).inDays;
  if (days == 0) return 'Today, $time';
  if (days == 1) return 'Tomorrow, $time';
  return '${dt.day}/${dt.month}, $time';
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
