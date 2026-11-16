import 'package:flutter_test/flutter_test.dart';

/// Checks the pumped screen for SC-002 (research §11): tap targets big enough
/// on iOS and Android, a label on every tap target, readable text contrast,
/// and nothing overflowing when the text is twice its normal size.
Future<void> expectAccessible(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  } finally {
    semantics.dispose();
  }
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  try {
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'Overflow at text scale 2.0');
  } finally {
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pump();
  }
}
