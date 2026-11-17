import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/ui/common/value_choices.dart';

import '../../support/screen_checks.dart';

Future<List<int>> pumpChoices(WidgetTester tester, {required int picked}) async {
  final reported = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ValueChoices(
          values: const [1, 2, 3],
          label: (n) => 'Option $n',
          picked: picked,
          onPicked: reported.add,
        ),
      ),
    ),
  );
  return reported;
}

bool selected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

void main() {
  testWidgets('a chip per value, named by label, with the picked one highlighted', (tester) async {
    await pumpChoices(tester, picked: 2);

    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(selected(tester, 'Option 1'), isFalse);
    expect(selected(tester, 'Option 2'), isTrue);
    expect(selected(tester, 'Option 3'), isFalse);
    await expectAccessible(tester);
  });

  testWidgets('tapping a chip, the picked one included, reports its value', (tester) async {
    final reported = await pumpChoices(tester, picked: 2);

    await tester.tap(find.text('Option 3'));
    await tester.tap(find.text('Option 2'));

    expect(reported, [3, 2]);
  });
}
