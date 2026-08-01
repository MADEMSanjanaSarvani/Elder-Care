/// The screen the app is for.
///
/// One question, asked and answered in one glance: *what do I take now, and
/// did I already take it?* Everything else in CareHive — the alarms, the
/// notification button, the history, the family view — exists to keep this
/// list true.
///
/// Three deliberate refusals:
///
/// **No score, no streak, no congratulation.** A streak turns an honest "I
/// forgot" into a thing you lose by admitting. The moment marking a dose
/// honestly costs something, people stop doing it, and the record — the entire
/// product — quietly becomes fiction.
///
/// **A past dose nobody marked is not shown as missed.** It is shown as
/// unanswered, with both buttons still live, because that is all the app
/// actually knows. See `adherence.dart`.
///
/// **Times, never countdowns.** "Due in 12 minutes" is a number that is wrong
/// the second after it renders and demands you keep checking. "8:00 am" is
/// simply true.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/medications_repository.dart';

/// Today's doses for an elder, in time order, medicine names attached.
final todayDosesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, elderId) async {
  ref.watch(authStateProvider);
  return MedicationsRepository(ref.watch(supabaseClientProvider))
      .fetchTodayForElder(elderId);
});

/// Where a dose sits relative to now. Drives the grouping and nothing else —
/// the buttons are identical in every group, because a dose you forgot to mark
/// at breakfast must be just as easy to mark at lunch.
enum _Slot { unanswered, now, later, done }

class TodayScreen extends ConsumerWidget {
  const TodayScreen({
    required this.elderId,
    this.showAppBar = true,
    this.bottomPadding = SetuSpacing.xl,
    super.key,
  });

  final String elderId;

  /// False when hosted inside a shell that already provides a top bar.
  final bool showAppBar;

  /// Room to leave under the last card — the elder home floats a large SOS bar
  /// over the bottom of this list, and a dose card hidden behind it is a dose
  /// that does not get marked.
  final double bottomPadding;

  /// A dose is "now" from fifteen minutes before its time until an hour after.
  /// Wide on purpose: nobody takes a tablet to the minute, and a window that
  /// snaps shut at the exact time would push a dose into "unanswered" while the
  /// person is still walking to the kitchen.
  static const _early = Duration(minutes: 15);
  static const _grace = Duration(hours: 1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayDosesProvider(elderId));
    final t = Theme.of(context).textTheme.scaledForElderMode();

    final body = async.when(
      loading: () => const SetuLoading(),
      error: (err, stack) => const SetuErrorState(),
      data: (doses) {
        if (doses.isEmpty) {
          return SetuEmptyState(
            icon: Icons.medication_outlined,
            title: 'Nothing due today',
            message: doses.isEmpty
                ? 'When a medicine has dose times, they appear here — and the '
                    'phone will remind you at each one.'
                : '',
          );
        }

        final now = DateTime.now();
        final grouped = <_Slot, List<Map<String, dynamic>>>{
          for (final slot in _Slot.values) slot: <Map<String, dynamic>>[],
        };
        for (final dose in doses) {
          grouped[_slotFor(dose, now)]!.add(dose);
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(todayDosesProvider(elderId)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(SetuSpacing.lg, SetuSpacing.lg,
                SetuSpacing.lg, bottomPadding),
            children: [
              _Header(doses: doses, t: t),
              const SizedBox(height: SetuSpacing.lg),
              _Group(
                label: 'Now',
                doses: grouped[_Slot.now]!,
                elderId: elderId,
                t: t,
                emphasis: true,
              ),
              _Group(
                label: 'Not marked yet',
                hint: 'These times have passed. If you took them, say so — '
                    'nothing is held against you either way.',
                doses: grouped[_Slot.unanswered]!,
                elderId: elderId,
                t: t,
              ),
              _Group(
                label: 'Later today',
                doses: grouped[_Slot.later]!,
                elderId: elderId,
                t: t,
              ),
              _Group(
                label: 'Done',
                doses: grouped[_Slot.done]!,
                elderId: elderId,
                t: t,
              ),
            ],
          ),
        );
      },
    );

    if (!showAppBar) return body;
    return Scaffold(appBar: AppBar(title: const Text('Today')), body: body);
  }

  static _Slot _slotFor(Map<String, dynamic> dose, DateTime now) {
    final status = dose['status'] as String?;
    if (status != null && status != 'pending') return _Slot.done;

    final at = DateTime.tryParse(dose['scheduled_at'] as String? ?? '')?.toLocal();
    if (at == null) return _Slot.later;

    if (now.isBefore(at.subtract(_early))) return _Slot.later;
    if (now.isBefore(at.add(_grace))) return _Slot.now;
    return _Slot.unanswered;
  }
}

/// The one-line answer, above the list, so it can be read without scrolling.
class _Header extends StatelessWidget {
  const _Header({required this.doses, required this.t});

  final List<Map<String, dynamic>> doses;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    final total = doses.length;
    final answered = doses.where((d) => d['status'] != 'pending').length;
    final allDone = answered == total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: allDone
            ? SetuColors.verifiedLight.withValues(alpha: 0.14)
            : SetuColors.accentLight.withValues(alpha: 0.10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            allDone ? 'All marked for today' : '$answered of $total marked',
            style: t.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: allDone ? SetuColors.verifiedLight : SetuColors.accentLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            allDone
                ? 'Nothing left to do. The record for today is complete.'
                : 'Tap Taken when the tablet is in your hand — not before.',
            style: t.bodyLarge?.copyWith(color: SetuColors.mutedLight),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.doses,
    required this.elderId,
    required this.t,
    this.hint,
    this.emphasis = false,
  });

  final String label;
  final String? hint;
  final List<Map<String, dynamic>> doses;
  final String elderId;
  final TextTheme t;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    // An empty group is not rendered at all — a heading over nothing is a
    // small lie about there being something there.
    if (doses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: t.labelLarge?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
              color: emphasis ? SetuColors.accentLight : SetuColors.mutedLight,
            )),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!,
              style: t.bodyMedium?.copyWith(color: SetuColors.mutedLight)),
        ],
        const SizedBox(height: SetuSpacing.sm),
        for (final dose in doses) ...[
          _DoseCard(dose: dose, elderId: elderId, t: t, emphasis: emphasis),
          const SizedBox(height: SetuSpacing.sm),
        ],
        const SizedBox(height: SetuSpacing.md),
      ],
    );
  }
}

class _DoseCard extends ConsumerStatefulWidget {
  const _DoseCard({
    required this.dose,
    required this.elderId,
    required this.t,
    required this.emphasis,
  });

  final Map<String, dynamic> dose;
  final String elderId;
  final TextTheme t;
  final bool emphasis;

  @override
  ConsumerState<_DoseCard> createState() => _DoseCardState();
}

class _DoseCardState extends ConsumerState<_DoseCard> {
  bool _busy = false;

  Map<String, dynamic>? get _med =>
      widget.dose['elder_medications'] as Map<String, dynamic>?;

  Future<void> _mark(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      await MedicationsRepository(client).markDose(
        doseId: widget.dose['id'] as String,
        status: status,
        markedBy: userId,
        // Who marked it is part of the record: a doctor reading "taken" should
        // be able to tell whether the person themselves said so or a relative
        // assumed it from another room.
        markedVia:
            ref.read(currentProfileProvider).asData?.value?['role'] == 'elder'
                ? 'elder_self'
                : 'family_proxy',
      );
      ref.invalidate(todayDosesProvider(widget.elderId));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save that: $err')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Undo. Nobody taps the right button every time on a phone held in one hand
  /// with a glass of water in the other, and a record you cannot correct is one
  /// people stop trusting after the first mis-tap.
  Future<void> _unmark() => _mark('pending');

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final status = widget.dose['status'] as String? ?? 'pending';
    final at =
        DateTime.tryParse(widget.dose['scheduled_at'] as String? ?? '')?.toLocal();
    final name = _med?['name'] as String? ?? 'Medicine';
    final dosage = _med?['dosage'] as String?;
    final settled = status != 'pending';

    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.emphasis
              ? SetuColors.accentLight.withValues(alpha: 0.55)
              : SetuColors.borderLight,
          width: widget.emphasis ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: t.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    if (dosage != null && dosage.isNotEmpty)
                      Text(dosage,
                          style: t.bodyLarge
                              ?.copyWith(color: SetuColors.mutedLight)),
                  ],
                ),
              ),
              const SizedBox(width: SetuSpacing.md),
              Text(_clock(at),
                  style: t.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: SetuColors.mutedLight)),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
          if (settled)
            _SettledRow(
              status: status,
              takenAt: DateTime.tryParse(
                      widget.dose['taken_at'] as String? ?? '')
                  ?.toLocal(),
              t: t,
              onUndo: _busy ? null : _unmark,
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    // Big enough to hit without looking, which is how it will
                    // actually be used.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: SetuColors.verifiedLight,
                    ),
                    onPressed: _busy ? null : () => _mark('taken'),
                    child: Text('Taken',
                        style: t.titleMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: SetuSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: _busy ? null : () => _mark('skipped'),
                    child: Text('Not taken',
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _clock(DateTime? at) {
    if (at == null) return '';
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${at.hour < 12 ? 'am' : 'pm'}';
  }
}

class _SettledRow extends StatelessWidget {
  const _SettledRow({
    required this.status,
    required this.takenAt,
    required this.t,
    required this.onUndo,
  });

  final String status;
  final DateTime? takenAt;
  final TextTheme t;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final taken = status == 'taken';
    final color = taken ? SetuColors.verifiedLight : SetuColors.mutedLight;

    return Row(
      children: [
        Icon(taken ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            color: color, size: 26),
        const SizedBox(width: SetuSpacing.sm),
        Expanded(
          child: Text(
            taken
                ? (takenAt == null
                    ? 'Taken'
                    : 'Taken at ${_DoseCardState._clock(takenAt)}')
                : 'Marked as not taken',
            style: t.titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onUndo, child: const Text('Undo')),
      ],
    );
  }
}
