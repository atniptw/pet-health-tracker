import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/features/household/member_name_screen.dart';

import '../helpers.dart';

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

void main() {
  const household = Household(id: 'h1', name: 'The Den', memberIds: ['u1'], adminIds: []);
  late MockHouseholdRepository repository;

  void answerAddMemberName(Future<void> Function() answer) {
    when(
      () => repository.addMemberName(
        householdId: any(named: 'householdId'),
        uid: any(named: 'uid'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) => answer());
  }

  setUp(() {
    repository = MockHouseholdRepository();
    answerAddMemberName(() async {});
  });

  Future<void> pumpScreen(WidgetTester tester, {String? displayName = 'Tom'}) {
    return tester.pumpScoped(
      MemberNameScreen(
        household: household,
        user: fakeUser(uid: 'u1', displayName: displayName),
      ),
      overrides: [householdRepositoryProvider.overrideWithValue(repository)],
    );
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets("suggests the user's display name", (tester) async {
    await pumpScreen(tester);

    expect(find.text('The Den'), findsOneWidget);
    expect(fieldText(tester), 'Tom');
  });

  testWidgets('starts empty when the user has no display name', (tester) async {
    await pumpScreen(tester, displayName: null);
    expect(fieldText(tester), '');
  });

  testWidgets('saves the trimmed name', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), '  Dad  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => repository.addMemberName(householdId: 'h1', uid: 'u1', name: 'Dad')).called(1);
  });

  testWidgets('does nothing when the name is blank', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verifyNever(
      () => repository.addMemberName(
        householdId: any(named: 'householdId'),
        uid: any(named: 'uid'),
        name: any(named: 'name'),
      ),
    );
  });

  testWidgets('shows a spinner while saving', (tester) async {
    final completer = Completer<void>();
    answerAddMemberName(() => completer.future);

    await pumpScreen(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('shows the error when saving fails', (tester) async {
    answerAddMemberName(() async => throw Exception('permission denied'));

    await pumpScreen(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
