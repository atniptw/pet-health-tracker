import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/pet.dart';

/// A [PetRepository] whose `add` fails with an error naming the pet, as
/// sqflite's `DatabaseException` lists a statement's arguments, and which has
/// no archived pets.
class FailingPets implements PetRepository {
  @override
  Stream<List<Pet>> watchArchived() => Stream.value(const []);

  @override
  Future<Pet> add({required String name, required Species species}) =>
      Future.error(Exception('INSERT INTO pets failed, args [$name]'));

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
