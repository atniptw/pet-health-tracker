import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/features/household/household_members.dart';
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
    when(
      () => households.removeMember(
        householdId: any(named: 'householdId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer((_) async {});
    when(() => households.watchMemberNames('h1')).thenAnswer(
      (_) => Stream.value({'owner': 'Tom', 'sam': 'Sam', 'ann': 'Ann', 'gone': 'Former'}),
    );
  });

  Future<void> pumpMembers(WidgetTester tester, {required String uid}) async {
    await tester.pumpScoped(
      MembersScreen(household: household, uid: uid),
      overrides: [householdRepositoryProvider.overrideWithValue(households)],
    );
    myHouseholds.add([household]);
    await tester.pumpAndSettle();
  }

  /// The names of the people with a remove action.
  List<String> removable(WidgetTester tester) {
    return tester
        .widgetList<IconButton>(find.byType(IconButton))
        .map((button) => button.tooltip!.replaceFirst('Remove ', ''))
        .toList();
  }

  Future<void> confirmRemoving(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('Remove $name'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
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

  group('removing', () {
    testWidgets('an admin can remove members who are not admins', (tester) async {
      await pumpMembers(tester, uid: 'ann');

      expect(removable(tester), ['Sam', noNameYet]);
    });

    testWidgets('an admin cannot remove another admin', (tester) async {
      await pumpMembers(tester, uid: 'ann');

      myHouseholds.add([
        const Household(
          id: 'h1',
          name: 'The Den',
          memberIds: ['owner', 'sam', 'ann', 'nameless'],
          adminIds: ['owner', 'ann', 'sam'],
          ownerId: 'owner',
        ),
      ]);
      await tester.pumpAndSettle();

      expect(removable(tester), [noNameYet]);
    });

    testWidgets('the owner can remove anyone but themselves', (tester) async {
      await pumpMembers(tester, uid: 'owner');

      expect(removable(tester), ['Ann', 'Sam', noNameYet]);
    });

    testWidgets('members who are not admins cannot remove anyone', (tester) async {
      await pumpMembers(tester, uid: 'sam');

      expect(removable(tester), isEmpty);
    });

    testWidgets('asks first, saying the invite code stops working', (tester) async {
      await pumpMembers(tester, uid: 'owner');

      await tester.tap(find.byTooltip('Remove Sam'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Sam?'), findsOneWidget);
      expect(find.textContaining('"Former member"'), findsOneWidget);
      expect(find.textContaining('invite code stops working'), findsOneWidget);
    });

    testWidgets('removes them after confirming, waiting for the server', (tester) async {
      final removed = Completer<void>();
      when(() => households.removeMember(householdId: 'h1', uid: 'sam'))
          .thenAnswer((_) => removed.future);
      await pumpMembers(tester, uid: 'owner');

      await confirmRemoving(tester, 'Sam');
      await tester.pump();

      expect(find.text('Removing Sam…'), findsOneWidget);
      verify(() => households.removeMember(householdId: 'h1', uid: 'sam')).called(1);

      // Neither back nor tapping outside closes it while it waits.
      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(find.text('Removing Sam…'), findsOneWidget);

      removed.complete();
      await tester.pumpAndSettle();

      expect(find.text('Removing Sam…'), findsNothing);
      expect(find.byType(MembersScreen), findsOneWidget);
    });

    testWidgets('cancelling removes no one', (tester) async {
      await pumpMembers(tester, uid: 'owner');

      await tester.tap(find.byTooltip('Remove Sam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(
        () => households.removeMember(
          householdId: any(named: 'householdId'),
          uid: any(named: 'uid'),
        ),
      );
    });

    testWidgets('says so when removing fails', (tester) async {
      when(() => households.removeMember(householdId: 'h1', uid: 'sam'))
          .thenAnswer((_) async => throw Exception('offline'));
      await pumpMembers(tester, uid: 'owner');

      await confirmRemoving(tester, 'Sam');
      await tester.pumpAndSettle();

      expect(find.text('Removing Sam…'), findsNothing);
      expect(
        find.text("Couldn't remove Sam. Check your connection and try again."),
        findsOneWidget,
      );
    });

    testWidgets('no one can be removed once you are out of the household', (tester) async {
      await pumpMembers(tester, uid: 'owner');

      myHouseholds.add(const []);
      await tester.pumpAndSettle();

      expect(removable(tester), isEmpty);
    });
  });
}
