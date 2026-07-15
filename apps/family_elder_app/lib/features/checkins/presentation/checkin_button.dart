import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/checkin_repository.dart';

/// The fourth additive action on the elder home screen (PRD Part 4, Batch
/// 1, Module 3). A single tap either records today's check-in or, if
/// already recorded, shows that it's done — there's no separate
/// confirm step, since the elder-mode UX principle (PRD Part 3 §17) is
/// large, unambiguous, one-tap actions.
class DailyCheckInButton extends ConsumerStatefulWidget {
  const DailyCheckInButton({required this.elderId, super.key});

  final String elderId;

  @override
  ConsumerState<DailyCheckInButton> createState() =>
      _DailyCheckInButtonState();
}

class _DailyCheckInButtonState extends ConsumerState<DailyCheckInButton> {
  late Future<DateTime?> _lastCheckIn;
  bool _submitting = false;

  CheckInRepository get _repo =>
      CheckInRepository(ref.read(supabaseClientProvider));

  @override
  void initState() {
    super.initState();
    _lastCheckIn = _repo.lastCheckInToday(widget.elderId);
  }

  Future<void> _checkIn() async {
    setState(() => _submitting = true);
    try {
      await _repo.checkIn(elderId: widget.elderId);
      setState(() => _lastCheckIn = _repo.lastCheckInToday(widget.elderId));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not check in: $err')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DateTime?>(
      future: _lastCheckIn,
      builder: (context, snapshot) {
        final alreadyCheckedIn = snapshot.data != null;
        const color = SetuColors.verifiedLight;
        return Material(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: (alreadyCheckedIn || _submitting) ? null : _checkIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: SetuSpacing.xl, horizontal: SetuSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    alreadyCheckedIn
                        ? Icons.check_circle
                        : Icons.self_improvement_outlined,
                    size: 40,
                    color: color,
                  ),
                  const SizedBox(width: SetuSpacing.md),
                  Expanded(
                    child: Text(
                      alreadyCheckedIn
                          ? "Checked in today"
                          : "I'm doing fine today",
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
