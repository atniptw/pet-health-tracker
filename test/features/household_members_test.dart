import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/features/household/household_members.dart';

void main() {
  const household = Household(
    id: 'h1',
    name: 'The Den',
    memberIds: ['tom', 'nameless', 'ann', 'bob'],
    adminIds: ['tom'],
    ownerId: 'tom',
  );
  const names = {'tom': 'Tom', 'ann': 'ann', 'bob': 'Bob', 'gone': 'Former'};

  test('sorts named members by name, ignoring case, then those with no name', () {
    expect(sortedMembers(household, names), [
      (uid: 'ann', name: 'ann'),
      (uid: 'bob', name: 'Bob'),
      (uid: 'tom', name: 'Tom'),
      (uid: 'nameless', name: null),
    ]);
  });

  test('leaves out the member given as except', () {
    expect(sortedMembers(household, names, except: 'tom').map((m) => m.uid), [
      'ann',
      'bob',
      'nameless',
    ]);
  });
}
