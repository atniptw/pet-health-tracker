import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/history/event_tile.dart';
import 'package:pet_health_tracker/ui/log/pet_choices.dart';
import 'package:pet_health_tracker/ui/log/type_grid.dart';

import '../support/robot.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('001-US3-S3 001-US3-S4 001-FR-015 001-EC-08 001-EC-09: add Rex and Mia, log for '
      'Mia, archive Mia, then Rex, and restore Mia with her full history', (tester) async {
    final app = await openTestApp(now: DateTime(2026, 11, 14, 12));
    final robot = Robot(tester);
    await tester.pumpWidget(
      App(pets: app.pets, eventTypes: app.eventTypes, events: app.events, clock: app.clock),
    );
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> back([int times = 1]) async {
      for (var i = 0; i < times; i++) {
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    }

    Future<void> openPets() async {
      await tap(find.byTooltip('Menu'));
      await tap(find.text('Pets'));
    }

    Finder button(String text) => find.widgetWithText(TextButton, text);

    bool picked(String pet) =>
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, pet)).selected;

    await robot.addPet('Rex', Species.dog);
    await openPets();
    await tap(button('Add pet'));
    await robot.addPet('Mia', Species.cat);
    await back();
    await robot.logEvent('Vomiting', pet: 'Mia');
    expect(find.text('Saved: Vomiting for Mia'), findsOneWidget);

    // Archiving Mia leaves Rex as the only pet offered, with no pet choices.
    await robot.openHistory('Mia');
    await tap(button('Archive'));
    expect(find.text('Archived'), findsOneWidget);
    await back();
    expect(find.byType(PetChoices), findsNothing);
    expect(find.text('Rex'), findsOneWidget);
    expect(find.text('Mia'), findsNothing);
    expect(find.byType(TypeGrid), findsOneWidget);

    // Archiving Rex too asks for a first pet, with the archived pets in reach.
    await robot.openHistory('Rex');
    await tap(button('Archive'));
    await back();
    expect(find.text('Add your first pet'), findsOneWidget);
    await tap(button('See archived pets'));
    expect(find.widgetWithText(ListTile, 'Mia'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Rex'), findsOneWidget);

    // Restoring Mia offers her again, with her full history.
    await tap(find.widgetWithText(ListTile, 'Mia'));
    expect(find.byType(EventTile), findsOneWidget);
    await tap(button('Restore'));
    await back(2);
    expect(find.text('Add your first pet'), findsNothing);
    expect(find.text('Mia'), findsOneWidget);
    await robot.openHistory('Mia');
    expect(find.widgetWithText(EventTile, 'Vomiting'), findsOneWidget);
    await back();

    // With Rex restored as well, Mia is picked as the pet last logged for.
    await openPets();
    await tap(button('Archived pets'));
    await tap(find.widgetWithText(ListTile, 'Rex'));
    await tap(button('Restore'));
    await back(3);
    expect(find.byType(PetChoices), findsOneWidget);
    expect(picked('Mia'), isTrue);
    expect(picked('Rex'), isFalse);
  });
}
