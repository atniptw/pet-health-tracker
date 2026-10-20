import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/features/settings/transfer_ownership_screen.dart';

import '../../helpers.dart';

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

void main() {
  const household = Household(
    id: 'h1',
    name: 'The Den',
    memberIds: ['owner', 'sam', 'alex', 'nameless'],
    adminIds: ['owner'],
    ownerId: 'owner',
  );

  late MockHouseholdRepository households;

  setUp(() {
    households = MockHouseholdRepository();
    when(() => households.watchMemberNames('h1')).thenAnswer(
      (_) => Stream.value({'owner': 'Tom', 'sam': 'Sam', 'alex': 'Alex', 'gone': 'Former'}),
    );
    when(
      () => households.transferOwnership(
        householdId: any(named: 'householdId'),
        toUid: any(named: 'toUid'),
      ),
    ).thenAnswer((_) async {});
  });

  /// Opens the screen on top of a placeholder, as settings does.
  Future<void> open(WidgetTester tester) async {
    await tester.pumpScoped(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) =>
                  const TransferOwnershipScreen(household: household, uid: 'owner'),
            ),
          ),
          child: const Text('open'),
        ),
      ),
      overrides: [householdRepositoryProvider.overrideWithValue(households)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the other members by name', (tester) async {
    await open(tester);

    final names = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(names, ['Alex', 'Sam', 'No name yet']);
    expect(find.text('Tom'), findsNothing);
    expect(find.text('Former'), findsNothing);
  });

  testWidgets('makes the picked member the owner after confirming, then closes', (tester) async {
    await open(tester);

    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
    expect(find.text('Make Sam the owner?'), findsOneWidget);
    expect(find.textContaining("You'll stay an admin"), findsOneWidget);

    await tester.tap(find.text('Make owner'));
    await tester.pumpAndSettle();

    verify(() => households.transferOwnership(householdId: 'h1', toUid: 'sam')).called(1);
    expect(find.byType(TransferOwnershipScreen), findsNothing);
  });

  testWidgets('cancelling changes nothing', (tester) async {
    await open(tester);

    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => households.transferOwnership(
        householdId: any(named: 'householdId'),
        toUid: any(named: 'toUid'),
      ),
    );
    expect(find.byType(TransferOwnershipScreen), findsOneWidget);
  });
}
