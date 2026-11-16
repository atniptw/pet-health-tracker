import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/log/type_grid.dart';

/// Drives the app's screens in the spec's words.
class Robot {
  Robot(this.tester);

  final WidgetTester tester;

  /// On a screen with the pet fields: types [name], picks [species] and
  /// taps "Save".
  Future<void> addPet(String name, Species species) async {
    await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
    await tester.tap(find.widgetWithText(ChoiceChip, species.label));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  /// On the log screen: picks [pet] among the pet choices if given, taps
  /// the [type] button and, in the log sheet, "Save".
  Future<void> logEvent(String type, {String? pet}) async {
    if (pet != null) {
      await tester.tap(find.widgetWithText(ChoiceChip, pet));
      await tester.pump();
    }
    final button = find.descendant(
      of: find.byType(TypeGrid),
      matching: find.widgetWithText(FilledButton, type),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }
}
