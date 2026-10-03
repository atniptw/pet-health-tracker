import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/features/household/create_household_screen.dart';

import '../helpers.dart';

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

void main() {
  late MockHouseholdRepository repository;

  setUp(() {
    repository = MockHouseholdRepository();
    when(
      () => repository.createHousehold(
        name: any(named: 'name'),
        ownerUid: any(named: 'ownerUid'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> pumpScreen(WidgetTester tester, {String? displayName = 'Tom'}) {
    return tester.pumpScoped(
      CreateHouseholdScreen(
        user: fakeUser(uid: 'u1', displayName: displayName),
      ),
      overrides: [householdRepositoryProvider.overrideWithValue(repository)],
    );
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets("suggests a name from the user's display name", (tester) async {
    await pumpScreen(tester);

    expect(fieldText(tester), "Tom's Household");
  });

  testWidgets('suggests a generic name when the user has no display name', (tester) async {
    await pumpScreen(tester, displayName: null);
    expect(fieldText(tester), 'My Household');
  });

  testWidgets('suggests a generic name when the display name is empty', (tester) async {
    await pumpScreen(tester, displayName: '');
    expect(fieldText(tester), 'My Household');
  });

  testWidgets('creates the household with the trimmed name', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), '  The Den  ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verify(() => repository.createHousehold(name: 'The Den', ownerUid: 'u1')).called(1);
  });

  testWidgets('does nothing when the name is blank', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verifyNever(
      () => repository.createHousehold(
        name: any(named: 'name'),
        ownerUid: any(named: 'ownerUid'),
      ),
    );
  });

  testWidgets('shows a spinner while creating', (tester) async {
    final completer = Completer<void>();
    when(
      () => repository.createHousehold(
        name: any(named: 'name'),
        ownerUid: any(named: 'ownerUid'),
      ),
    ).thenAnswer((_) => completer.future);

    await pumpScreen(tester);
    await tester.tap(find.text('Create'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Create'), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsOneWidget);
  });

  testWidgets('shows the error when creating fails', (tester) async {
    when(
      () => repository.createHousehold(
        name: any(named: 'name'),
        ownerUid: any(named: 'ownerUid'),
      ),
    ).thenThrow(Exception('permission denied'));

    await pumpScreen(tester);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });
}
