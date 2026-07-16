import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setu_core/setu_core.dart';
import 'package:caregiver_app/features/visit_tools/data/visit_tools_repository.dart';

/// The caregiver visit-tools activity/mood option sets are fixed vocabularies
/// the family-facing timeline and analytics read back. A silent change to
/// these strings would orphan historical logs, so pin the sets. Also a small
/// widget test that a chip row built from them renders and is selectable —
/// exercising the app's real design tokens without any Supabase dependency.
void main() {
  group('VisitToolsRepository option sets', () {
    test('activities are a stable, non-empty, unique set', () {
      const activities = VisitToolsRepository.availableActivities;
      expect(activities, isNotEmpty);
      expect(activities.toSet().length, activities.length,
          reason: 'no duplicates');
      expect(activities, contains('walked'));
      expect(activities, contains('other'));
    });

    test('moods are the fixed four-point scale', () {
      expect(
        VisitToolsRepository.availableMoods,
        ['content', 'okay', 'low', 'agitated'],
      );
    });
  });

  testWidgets('mood ChoiceChips render and reflect selection', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Wrap(
              spacing: SetuSpacing.sm,
              children: [
                for (final mood in VisitToolsRepository.availableMoods)
                  ChoiceChip(
                    label: Text(mood),
                    selected: selected == mood,
                    onSelected: (v) => setState(() => selected = v ? mood : null),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // All four moods are on screen.
    for (final mood in VisitToolsRepository.availableMoods) {
      expect(find.text(mood), findsOneWidget);
    }

    // Tapping one selects it.
    await tester.tap(find.text('content'));
    await tester.pump();
    final chip = tester.widget<ChoiceChip>(
      find.ancestor(of: find.text('content'), matching: find.byType(ChoiceChip)),
    );
    expect(chip.selected, isTrue);
  });
}
