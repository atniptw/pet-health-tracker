import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/features/household/household_providers.dart';
import 'package:pet_health_tracker/features/household/join_household_screen.dart';

import '../helpers.dart';

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

void main() {
  late MockHouseholdRepository repository;
  late FakeLastHouseholdStore store;

  void answerJoin(Future<String> Function() answer) {
    when(
      () => repository.joinHousehold(
        code: any(named: 'code'),
        uid: any(named: 'uid'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) => answer());
  }

  setUp(() {
    repository = MockHouseholdRepository();
    store = FakeLastHouseholdStore();
    answerJoin(() async => 'h2');
  });

  /// Opens the join screen on top of a placeholder, as the app does.
  Future<void> pumpJoin(WidgetTester tester, {String? displayName = 'Tom'}) async {
    await tester.pumpScoped(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => JoinHouseholdScreen(
                user: fakeUser(uid: 'u1', displayName: displayName),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
      overrides: [
        householdRepositoryProvider.overrideWithValue(repository),
        lastHouseholdStoreProvider.overrideWithValue(store),
      ],
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  final codeField = find.widgetWithText(TextField, 'Invite code');
  final nameField = find.widgetWithText(TextField, 'Your name');

  void verifyNoJoin() => verifyNever(
    () => repository.joinHousehold(
      code: any(named: 'code'),
      uid: any(named: 'uid'),
      name: any(named: 'name'),
    ),
  );

  testWidgets("suggests the user's display name", (tester) async {
    await pumpJoin(tester);
    expect(tester.widget<TextField>(nameField).controller!.text, 'Tom');
  });

  testWidgets('the code field has autocorrect and suggestions off', (tester) async {
    await pumpJoin(tester);

    final field = tester.widget<TextField>(codeField);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
  });

  testWidgets('joins with the code as typed and the trimmed name, then opens it', (tester) async {
    await pumpJoin(tester);
    await tester.enterText(codeField, 'Acorn tulip shelf ');
    await tester.enterText(nameField, '  Dad ');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    verify(() => repository.joinHousehold(code: 'Acorn tulip shelf ', uid: 'u1', name: 'Dad'))
        .called(1);
    expect(store.saved['u1'], 'h2');
    expect(find.byType(JoinHouseholdScreen), findsNothing);
  });

  testWidgets('does nothing without a code or a name', (tester) async {
    await pumpJoin(tester);
    await tester.enterText(codeField, '   ');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    verifyNoJoin();

    await tester.enterText(codeField, 'acorn tulip shelf');
    await tester.enterText(nameField, ' ');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    verifyNoJoin();
  });

  testWidgets('shows a spinner while joining', (tester) async {
    final completer = Completer<String>();
    answerJoin(() => completer.future);

    await pumpJoin(tester);
    await tester.enterText(codeField, 'acorn tulip shelf');
    await tester.tap(find.text('Join'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Join'), findsNothing);

    completer.complete('h2');
    await tester.pumpAndSettle();
  });

  testWidgets('says when the code matches nothing, and stays open', (tester) async {
    answerJoin(() async => throw const InviteNotFoundException());

    await pumpJoin(tester);
    await tester.enterText(codeField, 'acorn tulip shelf');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(
      find.text('No household found for that code. Check the spelling, or ask for a new code.'),
      findsOneWidget,
    );
    expect(find.byType(JoinHouseholdScreen), findsOneWidget);
    expect(store.saved, isEmpty);
  });
}
