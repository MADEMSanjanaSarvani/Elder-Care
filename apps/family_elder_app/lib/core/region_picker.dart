import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import 'providers.dart';

/// An elder's current region row, for showing where they live.
final elderRegionProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, elderId) async {
  final elder = await ref.watch(elderProfileByIdProvider(elderId).future);
  final regionId = elder?['region_id'] as String?;
  if (regionId == null) return null;
  final regions = await ref.watch(regionsProvider.future);
  for (final row in regions) {
    if (row['id'] == regionId) return row;
  }
  return null;
});

/// Moves an elder to a different region and refreshes everything keyed off it.
///
/// Region is not cosmetic — it decides which doctors the family is shown and
/// which caregivers can be booked — so the change has to invalidate those
/// reads, or a family that moved their mother to Chennai keeps being offered
/// Vizag clinics for the rest of the session.
Future<void> setElderRegion(
  WidgetRef ref, {
  required String elderId,
  required String regionId,
}) async {
  await ref
      .read(supabaseClientProvider)
      .from('elder_profiles')
      .update({'region_id': regionId}).eq('id', elderId);
  ref.invalidate(elderProfileByIdProvider(elderId));
  ref.invalidate(myElderProfilesProvider);
}

/// Picks the state or city an elder lives in, and says plainly whether SETU
/// operates there.
///
/// A dropdown of 37 places with no status would be a lie by omission: picking
/// Kerala looks identical to picking Vizag, and the family only discovers the
/// difference when the caregiver list comes back empty with no explanation. So
/// the live ones sort to the top and carry a green LIVE chip, and choosing one
/// of the rest shows what actually happens next — the person can still be
/// added, medicines and reminders still work, there is just nobody to send yet.
class RegionPicker extends ConsumerWidget {
  const RegionPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regions = ref.watch(regionsProvider);
    return regions.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(prefixIcon: Icon(Icons.place_outlined)),
        child: Text('Loading places…',
            style: TextStyle(color: SetuColors.mutedLight)),
      ),
      // A failed region fetch must not block adding a person. The default
      // stays selected and the elder lands in the pilot region, which is the
      // same outcome as before this picker existed.
      error: (_, __) => const InputDecorator(
        decoration: InputDecoration(prefixIcon: Icon(Icons.place_outlined)),
        child: Text('Visakhapatnam',
            style: TextStyle(color: SetuColors.inkLight)),
      ),
      data: (rows) {
        final selected = rows.any((r) => r['code'] == value) ? value : null;
        final isLive = rows.firstWhere(
              (r) => r['code'] == selected,
              orElse: () => const {'status': 'active'},
            )['status'] ==
            'active';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.place_outlined)),
              items: [
                for (final row in rows)
                  DropdownMenuItem(
                    value: row['code'] as String,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(row['display_name'] as String,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (row['status'] == 'active')
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  SetuColors.accentLight.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('LIVE',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: SetuColors.accentLight)),
                          ),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
            if (!isLive) ...[
              const SizedBox(height: SetuSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: SetuColors.peachLight),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                        "SETU doesn't have caregivers here yet. You can still "
                        'add them and use medicines, reminders and the timeline '
                        "— we'll let you know the moment we arrive.",
                        style: TextStyle(
                            fontSize: 12, color: SetuColors.mutedLight, height: 1.4)),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
