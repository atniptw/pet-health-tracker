import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';

void main() {
  group('ExistingType', () {
    test('holds the type id', () {
      expect(ExistingType('vomiting').typeId, 'vomiting');
    });

    test('choices of the same type are equal', () {
      expect(ExistingType('vomiting'), ExistingType('vomiting'));
      expect(ExistingType('vomiting').hashCode, ExistingType('vomiting').hashCode);
    });

    test('choices of different types are not equal', () {
      expect(ExistingType('vomiting'), isNot(ExistingType('seizure')));
    });
  });

  group('NewTypeName', () {
    test('holds the name as typed', () {
      expect(NewTypeName(' Ear shaking ').name, ' Ear shaking ');
    });

    test('choices of the same name are equal', () {
      expect(NewTypeName('Ear shaking'), NewTypeName('Ear shaking'));
      expect(NewTypeName('Ear shaking').hashCode, NewTypeName('Ear shaking').hashCode);
    });

    test('choices of different names are not equal', () {
      expect(NewTypeName('Ear shaking'), isNot(NewTypeName('Ear scratching')));
    });
  });

  test('an existing type and a new name with the same text are not equal', () {
    expect(ExistingType('vomiting'), isNot(NewTypeName('vomiting')));
    expect(NewTypeName('vomiting'), isNot(ExistingType('vomiting')));
  });
}
