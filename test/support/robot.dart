import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/pet.dart';

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
}
