import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/features/settings/members_screen.dart';

import '../../helpers.dart';

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

void main() {
  const household = Household(
    id: 'h1',
    name: 'The Den',
    memberIds: ['owner', 'sam', 'ann', 'nameless'],
    adminIds: ['owner', 'ann'],
    ownerId: 'owner',
  );

  late MockHouseholdRepository households;
  late StreamController<List<Household>> myHouseholds;

  setUp(() {
    households = MockHouseholdRepository();
    myHouseholds = StreamController<List<Household>>.broadcast();
    addTearDown(myHouseholds.close);
    when(() => households.watchMyHouseholds(any())).thenAnswer((_) => myHouseholds.stream);
    when(() => households.watchMemberNames('h1')).thenAnswer(
      (_) => Stream.value({'owner': 'Tom', 'sam': 'Sam', 'ann': 'Ann', 'gone': 'Former'}),
    );
  });

  Future<void> pumpMembers(WidgetTester tester, {required String uid}) async {
    await tester.pumpScoped(
      MembersScreen(household: household, uid: uid),
      overrides: [householdRepositoryProvider.overrideWithValue(households)],
    );
    await tester.pumpAndSettle();
  }

  /// Each row's name and, if it has one, its labels.
  List<(String?, String?)> rows(WidgetTester tester) {
    return tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => ((tile.title! as Text).data, (tile.subtitle as Text?)?.data))
        .toList();
  }

  testWidgets('lists everyone in the household by name, with their role', (tester) async {
    await pumpMembers(tester, uid: 'sam');

    expect(rows(tester), [
      ('Ann', 'Admin'),
      ('Sam', 'You'),
      ('Tom', 'Owner'),
      ('No name yet', null),
    ]);
    expect(find.text('Former'), findsNothing);
  });

  testWidgets('marks which one is you', (tester) async {
    await pumpMembers(tester, uid: 'owner');

    expect(rows(tester), [
      ('Ann', 'Admin'),
      ('Sam', null),
      ('Tom', 'Owner · You'),
      ('No name yet', null),
    ]);
  });

  testWidgets('shows people joining and leaving while it is open', (tester) async {
    await pumpMembers(tester, uid: 'sam');

    myHouseholds.add([
      const Household(
        id: 'h1',
        name: 'The Den',
        memberIds: ['owner', 'sam', 'gone'],
        adminIds: ['owner'],
        ownerId: 'owner',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(rows(tester), [('Former', null), ('Sam', 'You'), ('Tom', 'Owner')]);
  });
}
