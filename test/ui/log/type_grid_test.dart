import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/built_in_event_types.dart';
import 'package:pet_health_tracker/domain/event_type.dart';
import 'package:pet_health_tracker/ui/log/type_grid.dart';

import '../../support/screen_checks.dart';

const earShaking = EventType(id: 'ear', name: 'Ear shaking', builtIn: false);

/// The grid for [types] in a scrolling screen; each tapped type is added to
/// the returned list, and a tap on "Something else" adds null.
Future<List<EventType?>> pumpGrid(WidgetTester tester, List<EventType> types) async {
  final taps = <EventType?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TypeGrid(types: types, onTap: taps.add, onSomethingElse: () => taps.add(null)),
          ],
        ),
      ),
    ),
  );
  return taps;
}

Finder button(String name) => find.widgetWithText(FilledButton, name);

void main() {
  testWidgets('001-FR-002: a button per type, in the given order', (tester) async {
    await pumpGrid(tester, [...builtInEventTypes, earShaking]);

    final labels = tester
        .widgetList<FilledButton>(find.byType(FilledButton))
        .map((button) => (button.child! as Text).data);
    expect(labels, [...builtInEventTypes.map((type) => type.name), 'Ear shaking']);
  });

  testWidgets('001-FR-002: tapping a button reports its type', (tester) async {
    final taps = await pumpGrid(tester, [...builtInEventTypes, earShaking]);

    await tester.tap(button('Vomiting'));
    await tester.ensureVisible(button('Ear shaking'));
    await tester.tap(button('Ear shaking'));

    expect(taps.map((type) => type?.id), ['vomiting', 'ear']);
  });

  testWidgets('"Something else" comes after the types and reports its tap', (tester) async {
    final taps = await pumpGrid(tester, builtInEventTypes.take(3).toList());

    final something = tester.getRect(find.widgetWithText(OutlinedButton, 'Something else'));
    final third = tester.getRect(button('Seizure'));
    expect(something.top, third.top);
    expect(something.left, greaterThan(third.right));
    expect(something.height, greaterThanOrEqualTo(TypeGrid.minButtonHeight));
    await tester.tap(find.text('Something else'));
    expect(taps, [null]);
  });

  testWidgets('the buttons are large, two to a row', (tester) async {
    await pumpGrid(tester, builtInEventTypes.take(3).toList());

    final first = tester.getRect(button('Vomiting'));
    final second = tester.getRect(button('Diarrhea'));
    final third = tester.getRect(button('Seizure'));
    expect(first.height, greaterThanOrEqualTo(TypeGrid.minButtonHeight));
    expect(second.top, first.top);
    expect(second.width, first.width);
    expect(third.top, greaterThan(first.bottom));
    expect(third.left, first.left);
  });

  testWidgets('the grid is accessible', (tester) async {
    await pumpGrid(tester, builtInEventTypes);

    await expectAccessible(tester);
  });
}
