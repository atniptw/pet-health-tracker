import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/pet.dart';

import 'test_app.dart';

void main() {
  test('the clock reads 2026-11-14 12:00 local and ids count up across repositories', () async {
    final app = await openTestApp();
    final noon = DateTime(2026, 11, 14, 12).toUtc();

    final rex = await app.pets.add(name: 'Rex', species: Species.dog);
    final logged = await app.events.log(
      petId: rex.id,
      type: NewTypeName('Ear shaking'),
      occurredAt: noon,
    );
    final bella = await app.pets.add(name: 'Bella', species: Species.cat);

    final storedPet = await app.pets.watch(rex.id).first;
    final storedEvent = await app.events.watch(logged.id).first;
    expect(storedPet!.createdAt, noon);
    expect(storedEvent!.createdAt, noon);
    expect(storedEvent.updatedAt, noon);
    expect(
      [rex.id, storedEvent.id, storedEvent.typeId, bella.id],
      ['id-1', 'id-2', 'id-3', 'id-4'],
    );
  });

  test('the clock reads the given now', () async {
    final now = DateTime(2026, 1, 2, 3);
    final app = await openTestApp(now: now);

    final rex = await app.pets.add(name: 'Rex', species: Species.dog);
    final logged = await app.events.log(
      petId: rex.id,
      type: ExistingType('vomiting'),
      occurredAt: now,
    );

    expect((await app.pets.watch(rex.id).first)!.createdAt, now.toUtc());
    expect((await app.events.watch(logged.id).first)!.createdAt, now.toUtc());
  });
}
