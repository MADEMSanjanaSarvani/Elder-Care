import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/hydration_repository.dart';

final hydrationTodayProvider =
    FutureProvider.family<HydrationToday, String>((ref, elderId) async {
  ref.watch(authStateProvider);
  return HydrationRepository(ref.watch(supabaseClientProvider)).today(elderId);
});

/// Water intake, from the wellness design's bento grid.
///
/// The other three tiles in that grid — sleep, steps, resting heart rate — all
/// need a wearable and are not built. This one is, because a glass of water is
/// something a person taps rather than something a sensor measures.
///
/// The eight dots are the whole interface. Counting to eight is legible at a
/// glance in a way "62%" is not, and tapping a big target to fill one in is
/// about the simplest interaction the app has — which is the point, for the
/// person it is aimed at.
class HydrationCard extends ConsumerStatefulWidget {
  const HydrationCard({super.key, required this.elderId});

  final String elderId;

  @override
  ConsumerState<HydrationCard> createState() => _HydrationCardState();
}

class _HydrationCardState extends ConsumerState<HydrationCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(HydrationRepository) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      await action(HydrationRepository(ref.read(supabaseClientProvider)));
      ref.invalidate(hydrationTodayProvider(widget.elderId));
      await ref.read(hydrationTodayProvider(widget.elderId).future);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Couldn't save that: $err")));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hydrationTodayProvider(widget.elderId)).asData?.value;
    final glasses = state?.glasses ?? 0;
    final target = state?.target ?? HydrationRepository.defaultTarget;

    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.lavenderLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        boxShadow: SetuSurfaces.of(context).cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SetuIconChip(
                  icon: Icons.water_drop, color: SetuColors.lavenderLight),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WATER TODAY',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: SetuColors.mutedLight)),
                    const SizedBox(height: 2),
                    Text('$glasses of $target glasses',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (glasses > 0)
                IconButton(
                  tooltip: 'Undo last glass',
                  onPressed: _busy
                      ? null
                      : () => _run((r) => r.undoLastGlass(widget.elderId)),
                  icon: const Icon(Icons.undo, color: SetuColors.mutedLight),
                ),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
          // One dot per glass. Filled dots are what has been drunk; tapping any
          // empty one adds a glass, so the whole row is the button.
          Semantics(
            label: '$glasses of $target glasses of water today',
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _busy || glasses >= target
                  ? null
                  : () => _run((r) => r.logGlass(widget.elderId)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SetuSpacing.sm),
                child: Row(
                  children: [
                    for (var i = 0; i < target; i++)
                      Expanded(
                        child: Container(
                          height: 30,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i < glasses
                                ? SetuColors.lavenderLight
                                : SetuColors.lavenderLight
                                    .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: SetuSpacing.sm),
          if (glasses >= target)
            const Row(
              children: [
                Icon(Icons.check_circle,
                    size: 18, color: SetuColors.verifiedLight),
                SizedBox(width: 6),
                Expanded(
                  child: Text("That's the target for today. Well done.",
                      style: TextStyle(
                          color: SetuColors.mutedLight, fontSize: 13)),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _busy ? null : () => _run((r) => r.logGlass(widget.elderId)),
                icon: const Icon(Icons.add),
                label: const Text('I drank a glass'),
              ),
            ),
        ],
      ),
    );
  }
}
