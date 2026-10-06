import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/catalog_repository.dart';

void main() {
  // Loading the bundled copy needs the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late CatalogRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = CatalogRepository(firestore, rootBundle);
  });

  test('loadBundled reads the catalog bundled with the app', () async {
    final catalog = await repository.loadBundled();

    expect(catalog.symptoms.map((symptom) => symptom.key), ['seizure', 'vomit', 'diarrhea']);
  });

  test('watchPublished emits null while nothing is published', () async {
    expect(await repository.watchPublished().first, isNull);
  });

  test('watchPublished emits the published catalog', () async {
    await firestore.doc('catalog/symptoms').set({
      'catalogVersion': 2,
      'formatVersion': 1,
      'symptoms': [
        {'key': 'cough', 'label': 'Cough', 'questions': <Object>[]},
      ],
    });

    final catalog = await repository.watchPublished().first;

    expect(catalog!.symptom('cough')!.label, 'Cough');
  });
}
