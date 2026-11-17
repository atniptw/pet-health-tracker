import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/log/type_grid.dart';

import 'pickers.dart';

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
  /// the [type] button and, in the log sheet, sets "When" to [at] (a day of
  /// the month the picker opens on) and the duration to [minutes] if given,
  /// and taps "Save".
  Future<void> logEvent(String type, {String? pet, DateTime? at, int? minutes}) async {
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
    if (at != null) await _setWhen(at);
    if (minutes != null) {
      await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '$minutes');
      await tester.pump();
    }
    await _save();
  }

  Future<void> _setWhen(DateTime at) async {
    await openPickers(tester);
    await pickDay(tester, at.day);
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    await pickTime(tester, hour, at.minute, at.hour < 12 ? 'AM' : 'PM');
  }

  /// On the log screen: picks [pet] among the pet choices if given, taps
  /// "Something else", types [name] under "What happened?", taps
  /// "Continue" and, in the log sheet, "Save".
  Future<void> logSomethingElse(String name, {String? pet}) async {
    if (pet != null) {
      await tester.tap(find.widgetWithText(ChoiceChip, pet));
      await tester.pump();
    }
    final button = find.widgetWithText(OutlinedButton, 'Something else');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'What happened?'), name);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await _save();
  }

  /// On the log screen: opens the menu's "My event types", taps "Remove"
  /// for [name] and goes back to the log screen.
  Future<void> removeEventType(String name) async {
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My event types'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, name),
        matching: find.widgetWithText(TextButton, 'Remove'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  /// On the log screen: picks [pet] among the pet choices if they show, and
  /// taps "History".
  Future<void> openHistory(String pet) async {
    final choice = find.widgetWithText(ChoiceChip, pet);
    if (choice.evaluate().isNotEmpty) {
      await tester.tap(choice);
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(TextButton, 'History'));
    await tester.pumpAndSettle();
  }

  Future<void> _save() async {
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }
}
