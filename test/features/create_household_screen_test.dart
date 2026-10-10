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
        ownerName: any(named: 'ownerName'),
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

  final householdField = find.widgetWithText(TextField, 'Household name');
  final ownerField = find.widgetWithText(TextField, 'Your name');

  String fieldText(WidgetTester tester, [Finder? field]) =>
      tester.widget<TextField>(field ?? householdField).controller!.text;

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
    await tester.enterText(householdField, '  The Den  ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verify(() => repository.createHousehold(name: 'The Den', ownerUid: 'u1', ownerName: 'Tom'))
        .called(1);
  });

  testWidgets("suggests the user's display name as their name", (tester) async {
    await pumpScreen(tester);
    expect(fieldText(tester, ownerField), 'Tom');
  });

  testWidgets('leaves the name empty when the user has no display name', (tester) async {
    await pumpScreen(tester, displayName: null);
    expect(fieldText(tester, ownerField), '');
  });

  testWidgets("creates the household with the owner's trimmed name", (tester) async {
    await pumpScreen(tester);
    await tester.enterText(ownerField, '  Dad  ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verify(
      () => repository.createHousehold(name: "Tom's Household", ownerUid: 'u1', ownerName: 'Dad'),
    ).called(1);
  });

  testWidgets('does nothing when your name is blank', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(ownerField, '   ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verifyNever(
      () => repository.createHousehold(
        name: any(named: 'name'),
        ownerUid: any(named: 'ownerUid'),
        ownerName: any(named: 'ownerName'),
      ),
    );
  });

  testWidgets('does nothing when the name is blank', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(householdField, '   ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verifyNever(
      () => repository.createHousehold(
        name: any(named: 'name'),
        ownerUid: any(named: 'ownerUid'),
        ownerName: any(named: 'ownerName'),
      ),
    );
  });

  testWidgets('shows a spinner while creating', (tester) async {
    final completer = Completer<void>();
    when(
      () => repository.createHousehold(
        name: any(named: 'name'),
        ownerUid: any(named: 'ownerUid'),
        ownerName: any(named: 'ownerName'),
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
        ownerName: any(named: 'ownerName'),
      ),
    ).thenThrow(Exception('permission denied'));

    await pumpScreen(tester);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });
}
