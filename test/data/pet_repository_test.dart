import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PetRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = PetRepository(firestore);
  });

  CollectionReference<Map<String, dynamic>> pets(String householdId) =>
      firestore.collection('households').doc(householdId).collection('pets');

  group('addPet', () {
    test('writes only the required fields when nothing optional is given', () async {
      await repository.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog);

      final data = (await pets('h1').get()).docs.single.data();
      expect(
        data.keys,
        unorderedEquals(<String>['name', 'species', 'createdAt', 'updatedAt', 'schemaVersion']),
      );
      expect(data['name'], 'Boogie');
      expect(data['species'], 'dog');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['schemaVersion'], 1);
    });

    test('writes the optional fields when given', () async {
      await repository.addPet(
        householdId: 'h1',
        name: 'Pootz',
        species: Species.cat,
        breed: 'Tabby',
        birthDate: DateTime(2019, 4, 1),
        sex: Sex.female,
      );

      final data = (await pets('h1').get()).docs.single.data();
      expect(data['species'], 'cat');
      expect(data['breed'], 'Tabby');
      expect(data['birthDate'], '2019-04-01');
      expect(data['sex'], 'female');
    });

    test('leaves out a blank breed', () async {
      await repository.addPet(householdId: 'h1', name: 'Rex', species: Species.dog, breed: '');

      expect((await pets('h1').get()).docs.single.data().containsKey('breed'), isFalse);
    });
  });

  group('updatePet', () {
    Future<String> addPootz() async {
      await repository.addPet(
        householdId: 'h1',
        name: 'Pootz',
        species: Species.cat,
        breed: 'Tabby',
        birthDate: DateTime(2019, 4, 1),
        sex: Sex.female,
      );
      return (await pets('h1').get()).docs.single.id;
    }

    test('changes the fields and keeps createdAt', () async {
      final id = await addPootz();
      final createdAt = (await pets('h1').doc(id).get()).data()!['createdAt'];

      await repository.updatePet(
        householdId: 'h1',
        petId: id,
        name: 'Pootz Jr',
        species: Species.other,
        breed: 'Ferret',
        birthDate: DateTime(2020, 12, 31),
        sex: Sex.male,
      );

      final data = (await pets('h1').doc(id).get()).data()!;
      expect(data['name'], 'Pootz Jr');
      expect(data['species'], 'other');
      expect(data['breed'], 'Ferret');
      expect(data['birthDate'], '2020-12-31');
      expect(data['sex'], 'male');
      expect(data['createdAt'], createdAt);
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['schemaVersion'], 1);
    });

    test('removes optional fields that are cleared', () async {
      final id = await addPootz();

      await repository.updatePet(
        householdId: 'h1',
        petId: id,
        name: 'Pootz',
        species: Species.cat,
        breed: '',
      );

      final data = (await pets('h1').doc(id).get()).data()!;
      expect(
        data.keys,
        unorderedEquals(<String>['name', 'species', 'createdAt', 'updatedAt', 'schemaVersion']),
      );
    });
  });

  group('watchPets', () {
    test('emits an empty list when the household has no pets', () async {
      expect(await repository.watchPets('h1').first, isEmpty);
    });

    test("emits the household's pets sorted by name, ignoring case", () async {
      await repository.addPet(householdId: 'h1', name: 'pootz', species: Species.cat);
      await repository.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog);
      await repository.addPet(householdId: 'h2', name: 'Elsewhere', species: Species.dog);

      final result = await repository.watchPets('h1').first;

      expect(result.map((p) => p.name), ['Boogie', 'pootz']);
    });

    test('leaves out archived pets', () async {
      await repository.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog);
      await pets('h1').add({
        'name': 'Old Timer',
        'species': 'dog',
        'archivedAt': Timestamp.now(),
        'schemaVersion': 1,
      });

      expect((await repository.watchPets('h1').first).map((p) => p.name), ['Boogie']);
    });

    test('reads every field back', () async {
      await repository.addPet(
        householdId: 'h1',
        name: 'Pootz',
        species: Species.cat,
        breed: 'Tabby',
        birthDate: DateTime(2019, 4, 1),
        sex: Sex.male,
      );

      final pet = (await repository.watchPets('h1').first).single;

      expect(pet.id, isNotEmpty);
      expect(pet.name, 'Pootz');
      expect(pet.species, Species.cat);
      expect(pet.breed, 'Tabby');
      expect(pet.birthDate, DateTime(2019, 4, 1));
      expect(pet.sex, Sex.male);
    });

    test('reads values it does not know as other or unset', () async {
      await pets('h1').add({
        'name': 'Hoppy',
        'species': 'rabbit',
        'sex': 'something-new',
        'birthDate': 'not a date',
        'schemaVersion': 1,
      });

      final pet = (await repository.watchPets('h1').first).single;

      expect(pet.species, Species.other);
      expect(pet.sex, isNull);
      expect(pet.birthDate, isNull);
      expect(pet.breed, isNull);
    });

    test('emits again when a pet is added', () async {
      final names = repository.watchPets('h1').map((list) => list.map((p) => p.name).toList());

      final expectation = expectLater(
        names,
        emitsInOrder(<List<String>>[
          <String>[],
          <String>['Boogie'],
        ]),
      );
      await repository.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog);
      await expectation;
    });
  });

  test('species and sex have labels', () {
    expect(Species.values.map((s) => s.label), ['Dog', 'Cat', 'Other']);
    expect(Sex.values.map((s) => s.label), ['Female', 'Male', 'Unknown']);
  });
}
