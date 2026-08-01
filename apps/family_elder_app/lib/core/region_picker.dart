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

/// Moves an elder to a different region and refreshes anything keyed off it.
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

/// Picks the state or city an elder lives in.
///
/// This used to carry LIVE chips and a "we don't have caregivers here yet"
/// warning, because where somebody lived decided whether anyone could be sent
/// to them. Nothing is sent now — a medicine record works identically in
/// Visakhapatnam and in Kochi — so the chips and the warning are gone and this
/// is what it looks like: a plain question about where they live, kept because
/// it is worth having on a medical record.
class RegionPicker extends ConsumerWidget {
  const RegionPicker({super.key, required this.value, required this.onChanged});

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
        return DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          decoration:
              const InputDecoration(prefixIcon: Icon(Icons.place_outlined)),
          items: [
            for (final row in rows)
              DropdownMenuItem(
                value: row['code'] as String,
                child: Text(row['display_name'] as String,
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        );
      },
    );
  }
}
