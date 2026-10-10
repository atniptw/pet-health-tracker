import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/app.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';
import 'package:pet_health_tracker/features/household/create_household_screen.dart';
import 'package:pet_health_tracker/features/household/home_screen.dart';
import 'package:pet_health_tracker/features/household/household_providers.dart';
import 'package:pet_health_tracker/features/household/member_name_screen.dart';

import '../helpers.dart';

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  final user = fakeUser(uid: 'u1');

  testWidgets('shows a spinner while the household loads', (tester) async {
    final repository = MockHouseholdRepository();
    when(() => repository.watchMyHouseholds('u1')).thenAnswer((_) => const Stream.empty());

    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [
        householdRepositoryProvider.overrideWithValue(repository),
        lastHouseholdStoreProvider.overrideWithValue(FakeLastHouseholdStore()),
      ],
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows create-household when the user has none', (tester) async {
    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(FakeFirebaseFirestore())),
        lastHouseholdStoreProvider.overrideWithValue(FakeLastHouseholdStore()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreateHouseholdScreen), findsOneWidget);
  });

  testWidgets('shows home when the user has a household', (tester) async {
    final repository = HouseholdRepository(FakeFirebaseFirestore());
    await repository.createHousehold(name: 'The Den', ownerUid: 'u1', ownerName: 'Tom');

    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [
        householdRepositoryProvider.overrideWithValue(repository),
        petRepositoryProvider.overrideWithValue(PetRepository(FakeFirebaseFirestore())),
        lastHouseholdStoreProvider.overrideWithValue(FakeLastHouseholdStore()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('The Den'), findsWidgets);
  });

  testWidgets('asks a member with no name for one, then shows home', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc('households/h1').set({
      'name': 'The Den',
      'memberIds': ['u1'],
      'adminIds': ['u1'],
    });

    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(firestore)),
        petRepositoryProvider.overrideWithValue(PetRepository(FakeFirebaseFirestore())),
        lastHouseholdStoreProvider.overrideWithValue(FakeLastHouseholdStore()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(MemberNameScreen), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect((await firestore.doc('households/h1/members/u1').get()).data()!['name'], 'Tom');
  });

  group('more than one household', () {
    late FakeFirebaseFirestore firestore;
    late FakeLastHouseholdStore store;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      store = FakeLastHouseholdStore();
      for (final (id, name) in [('h1', 'Cabin'), ('h2', 'The Den')]) {
        await firestore.doc('households/$id').set({
          'name': name,
          'memberIds': ['u1'],
          'adminIds': ['u1'],
        });
        await firestore.doc('households/$id/members/u1').set({'name': 'Tom'});
      }
    });

    Future<void> pumpGate(WidgetTester tester) async {
      await tester.pumpScoped(
        HouseholdGate(user: user),
        overrides: [
          householdRepositoryProvider.overrideWithValue(HouseholdRepository(firestore)),
          petRepositoryProvider.overrideWithValue(PetRepository(FakeFirebaseFirestore())),
          lastHouseholdStoreProvider.overrideWithValue(store),
        ],
      );
      await tester.pumpAndSettle();
    }

    String openHousehold(WidgetTester tester) =>
        tester.widget<HomeScreen>(find.byType(HomeScreen)).household.name;

    testWidgets('opens the first by name when none was opened before', (tester) async {
      await pumpGate(tester);
      expect(openHousehold(tester), 'Cabin');
    });

    testWidgets('opens the household last opened on this device', (tester) async {
      store.saved['u1'] = 'h2';
      await pumpGate(tester);
      expect(openHousehold(tester), 'The Den');
    });

    testWidgets('opens the first when the last one opened is gone', (tester) async {
      store.saved['u1'] = 'left-this-one';
      await pumpGate(tester);
      expect(openHousehold(tester), 'Cabin');
    });

    testWidgets('switches from the title and remembers the choice', (tester) async {
      await pumpGate(tester);

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      expect(find.widgetWithIcon(ListTile, Icons.check), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Cabin'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'The Den'));
      await tester.pumpAndSettle();

      expect(openHousehold(tester), 'The Den');
      expect(store.saved['u1'], 'h2');
    });

    testWidgets('picking the open household just closes the sheet', (tester) async {
      await pumpGate(tester);

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Cabin'));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNothing);
      expect(openHousehold(tester), 'Cabin');
      expect(store.saved, isEmpty);
    });
  });

  testWidgets('creates another household from the switcher and opens it', (tester) async {
    final auth = MockFirebaseAuth();
    when(() => auth.currentUser).thenReturn(user);
    final repository = HouseholdRepository(FakeFirebaseFirestore());
    await repository.createHousehold(name: 'The Den', ownerUid: 'u1', ownerName: 'Tom');

    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        householdRepositoryProvider.overrideWithValue(repository),
        petRepositoryProvider.overrideWithValue(PetRepository(FakeFirebaseFirestore())),
        lastHouseholdStoreProvider.overrideWithValue(FakeLastHouseholdStore()),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a household'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateHouseholdScreen), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Household name'), 'Cabin');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateHouseholdScreen), findsNothing);
    expect(tester.widget<HomeScreen>(find.byType(HomeScreen)).household.name, 'Cabin');
  });

  testWidgets('shows the error and retries on tap', (tester) async {
    final repository = MockHouseholdRepository();
    when(() => repository.watchMyHouseholds('u1')).thenAnswer((_) => Stream.error('offline'));

    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [
        householdRepositoryProvider.overrideWithValue(repository),
        lastHouseholdStoreProvider.overrideWithValue(FakeLastHouseholdStore()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('offline'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    verify(() => repository.watchMyHouseholds('u1')).called(2);
  });
}
