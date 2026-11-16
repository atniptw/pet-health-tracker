import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/pet.dart';

void main() {
  final createdAt = DateTime.utc(2026, 11, 14, 18);

  Pet pet() => Pet(id: 'pet-1', name: 'Biscuit', species: Species.dog, createdAt: createdAt);

  group('Species', () {
    test('001-FR-001: species are Dog, Cat and Other with fixed ids', () {
      expect(Species.values.map((s) => s.id), ['dog', 'cat', 'other']);
      expect(Species.values.map((s) => s.label), ['Dog', 'Cat', 'Other']);
    });

    test('fromId finds each species by its id', () {
      for (final species in Species.values) {
        expect(Species.fromId(species.id), species);
      }
    });

    test('fromId throws for an unknown id', () {
      expect(() => Species.fromId('hamster'), throwsArgumentError);
    });
  });

  group('Pet', () {
    test('001-FR-001: a pet has a name and species and is active when added', () {
      final added = pet();
      expect(added.id, 'pet-1');
      expect(added.name, 'Biscuit');
      expect(added.species, Species.dog);
      expect(added.archived, isFalse);
      expect(added.createdAt, createdAt);
    });

    test('pets with the same fields are equal', () {
      expect(pet(), pet());
      expect(pet().hashCode, pet().hashCode);
    });

    test('pets differing in any field are not equal', () {
      expect(pet(), isNot(pet().copyWith(id: 'pet-2')));
      expect(pet(), isNot(pet().copyWith(name: 'Mochi')));
      expect(pet(), isNot(pet().copyWith(species: Species.cat)));
      expect(pet(), isNot(pet().copyWith(archived: true)));
      expect(pet(), isNot(pet().copyWith(createdAt: createdAt.add(const Duration(seconds: 1)))));
    });

    test('001-FR-001: editing name and species with copyWith keeps the id', () {
      final edited = pet().copyWith(name: 'Mochi', species: Species.cat);
      expect(edited.id, 'pet-1');
      expect(edited.name, 'Mochi');
      expect(edited.species, Species.cat);
      expect(edited.archived, isFalse);
      expect(edited.createdAt, createdAt);
    });

    test('copyWith with no changes gives an equal pet', () {
      expect(pet().copyWith(), pet());
    });
  });

  group('validPetName', () {
    test('001-FR-001: returns the name trimmed', () {
      expect(validPetName('  Biscuit '), 'Biscuit');
    });

    test('001-FR-001: a single character is allowed', () {
      expect(validPetName('a'), 'a');
      expect(validPetName(' a '), 'a');
    });

    test('001-FR-001: a name empty after trimming is refused', () {
      expect(() => validPetName(''), throwsArgumentError);
      expect(() => validPetName('   '), throwsArgumentError);
    });

    test('001-FR-001: 40 characters are allowed, 41 are refused', () {
      expect(validPetName('a' * 40), 'a' * 40);
      expect(validPetName(' ${'a' * 40} '), 'a' * 40);
      expect(() => validPetName('a' * 41), throwsArgumentError);
    });

    test('counts each emoji as one character', () {
      final name = '🐶' * 40;
      expect(validPetName(name), name);
      expect(() => validPetName('🐶' * 41), throwsArgumentError);
    });
  });
}
