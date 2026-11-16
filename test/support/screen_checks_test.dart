import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_checks.dart';

/// A tappable box of [size] with an optional screen-reader [label].
Widget tapTarget(double size, {String? label = 'Open'}) => Semantics(
  label: label,
  child: GestureDetector(
    onTap: () {},
    child: SizedBox.square(dimension: size),
  ),
);

Future<void> pumpScreen(WidgetTester tester, Widget body) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: body)),
  ),
);

Matcher failsWith(String message) =>
    throwsA(isA<TestFailure>().having((e) => e.message, 'message', contains(message)));

void main() {
  testWidgets('a labeled button with readable text passes', (tester) async {
    await pumpScreen(tester, ElevatedButton(onPressed: () {}, child: const Text('Save')));

    await expectAccessible(tester);
  });

  testWidgets('a tap target under 48 by 48 fails the Android check', (tester) async {
    await pumpScreen(tester, tapTarget(46));

    await expectLater(() => expectAccessible(tester), failsWith('at least Size(48.0, 48.0)'));
  });

  testWidgets('a tap target under 44 by 44 fails the iOS check', (tester) async {
    await pumpScreen(tester, tapTarget(40));

    await expectLater(() => expectAccessible(tester), failsWith('at least Size(44.0, 44.0)'));
  });

  testWidgets('a tap target with no label fails the label check', (tester) async {
    await pumpScreen(tester, tapTarget(48, label: null));

    await expectLater(() => expectAccessible(tester), failsWith('should have a semantic label'));
  });

  testWidgets('light grey text on white fails the contrast check', (tester) async {
    await pumpScreen(tester, const Text('Faint', style: TextStyle(color: Color(0xFFDDDDDD))));

    await expectLater(
      () => expectAccessible(tester),
      failsWith('Text contrast should follow WCAG'),
    );
  });

  testWidgets('text that fits at the normal size but not at 2.0 fails the overflow check', (
    tester,
  ) async {
    await pumpScreen(tester, const SizedBox(width: 120, child: Row(children: [Text('Vomiting')])));

    await expectLater(() => expectAccessible(tester), failsWith('text scale 2.0'));
    expect(tester.platformDispatcher.textScaleFactor, 1.0);
  });
}
