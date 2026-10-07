import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';
import 'package:pet_health_tracker/features/pets/all_pets_screen.dart';
import 'package:pet_health_tracker/features/pets/pet_form_screen.dart';
import 'package:pet_health_tracker/features/symptoms/pet_logs_screen.dart';

import '../../helpers.dart';

void main() {
  const household = Household(
    id: 'h1',
    name: 'The Den',
    memberIds: ['admin', 'member'],
    adminIds: ['admin'],
  );

  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final pets = PetRepository(firestore);
    await pets.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog, breed: 'Beagle');
    await pets.addPet(householdId: 'h1', name: 'Pootz', species: Species.cat);
  });

  Future<void> pumpAllPets(WidgetTester tester, {required String uid}) async {
    await tester.pumpScoped(
      AllPetsScreen(household: household, uid: uid),
      overrides: [
        petRepositoryProvider.overrideWithValue(PetRepository(firestore)),
        symptomLogRepositoryProvider.overrideWithValue(SymptomLogRepository(firestore)),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every pet', (tester) async {
    await pumpAllPets(tester, uid: 'member');

    expect(find.text('All pets'), findsOneWidget);
    expect(find.text('Dog · Beagle'), findsOneWidget);
    expect(find.text('Pootz'), findsOneWidget);
  });

  testWidgets("tapping a pet opens its history, knowing the user's role", (tester) async {
    await pumpAllPets(tester, uid: 'member');
    await tester.tap(find.text('Pootz'));
    await tester.pumpAndSettle();

    final screen = tester.widget<PetLogsScreen>(find.byType(PetLogsScreen));
    expect(
      (screen.householdId, screen.pet.name, screen.uid, screen.isAdmin),
      ('h1', 'Pootz', 'member', false),
    );
  });

  testWidgets('admins can add a pet', (tester) async {
    await pumpAllPets(tester, uid: 'admin');
    await tester.tap(find.byTooltip('Add pet'));
    await tester.pumpAndSettle();

    final form = tester.widget<PetFormScreen>(find.byType(PetFormScreen));
    expect((form.householdId, form.pet), ('h1', null));
  });

  testWidgets("members can't add a pet", (tester) async {
    await pumpAllPets(tester, uid: 'member');

    expect(find.byTooltip('Add pet'), findsNothing);
  });
}
