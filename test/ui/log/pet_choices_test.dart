import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/log/pet_choices.dart';

import '../../support/screen_checks.dart';

Pet pet(String id, String name) =>
    Pet(id: id, name: name, species: Species.dog, createdAt: DateTime.utc(2026, 11, 1));

final rex = pet('rex', 'Rex');
final mia = pet('mia', 'Mia');
final bo = pet('bo', 'Bo');

/// The choices for [pets] with [pickedId] picked, with the parent keeping the
/// pick; each picked id is added to the returned list.
Future<List<String>> pumpChoices(WidgetTester tester, List<Pet> pets, {String? pickedId}) async {
  final picks = <String>[];
  var picked = pickedId;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => PetChoices(
            pets: pets,
            pickedId: picked,
            onPicked: (id) {
              picks.add(id);
              setState(() => picked = id);
            },
          ),
        ),
      ),
    ),
  );
  return picks;
}

Finder chip(String name) => find.widgetWithText(ChoiceChip, name);

bool selected(WidgetTester tester, String name) => tester.widget<ChoiceChip>(chip(name)).selected;

void main() {
  testWidgets('001-FR-007: a chip per active pet, in the order given', (tester) async {
    await pumpChoices(tester, [rex, mia, bo], pickedId: 'rex');

    expect(find.byType(ChoiceChip), findsNWidgets(3));
    final dx = [
      for (final name in ['Rex', 'Mia', 'Bo']) tester.getTopLeft(chip(name)).dx,
    ];
    expect(dx, orderedEquals([...dx]..sort()));
  });

  testWidgets('001-FR-007: the picked pet is highlighted, no question shown', (tester) async {
    await pumpChoices(tester, [rex, mia], pickedId: 'mia');

    expect(selected(tester, 'Mia'), isTrue);
    expect(selected(tester, 'Rex'), isFalse);
    expect(find.text('Who is this for?'), findsNothing);
  });

  testWidgets('001-FR-007: none picked → "Who is this for?" and no chip highlighted', (
    tester,
  ) async {
    await pumpChoices(tester, [rex, mia]);

    expect(find.text('Who is this for?'), findsOneWidget);
    expect(selected(tester, 'Rex'), isFalse);
    expect(selected(tester, 'Mia'), isFalse);
  });

  testWidgets('001-FR-007: a picked id not among the pets → none picked', (tester) async {
    await pumpChoices(tester, [rex, mia], pickedId: 'archived-pet');

    expect(find.text('Who is this for?'), findsOneWidget);
    expect(selected(tester, 'Rex'), isFalse);
    expect(selected(tester, 'Mia'), isFalse);
  });

  testWidgets('001-FR-007: tapping a pet picks it and hides the question', (tester) async {
    final picks = await pumpChoices(tester, [rex, mia]);

    await tester.tap(chip('Mia'));
    await tester.pump();

    expect(picks, ['mia']);
    expect(selected(tester, 'Mia'), isTrue);
    expect(find.text('Who is this for?'), findsNothing);
  });

  testWidgets('001-FR-007: the picked pet is changeable', (tester) async {
    final picks = await pumpChoices(tester, [rex, mia], pickedId: 'rex');

    await tester.tap(chip('Mia'));
    await tester.pump();

    expect(picks, ['mia']);
    expect(selected(tester, 'Mia'), isTrue);
    expect(selected(tester, 'Rex'), isFalse);
  });

  testWidgets('001-FR-007: tapping the picked pet again keeps it picked', (tester) async {
    final picks = await pumpChoices(tester, [rex, mia], pickedId: 'rex');

    await tester.tap(chip('Rex'));
    await tester.pump();

    expect(picks, isEmpty);
    expect(selected(tester, 'Rex'), isTrue);
    expect(find.text('Who is this for?'), findsNothing);
  });

  testWidgets('001-FR-007: the pet choices are accessible', (tester) async {
    await pumpChoices(tester, [rex, mia, bo, pet('long', 'Sir Reginald Fluffington the Third')]);

    await expectAccessible(tester);
  });
}
