import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/catalog_repository.dart';
import 'package:pet_health_tracker/data/symptom_catalog.dart';
import 'package:pet_health_tracker/features/symptoms/symptom_providers.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

SymptomCatalog catalogOf(String key) => SymptomCatalog.fromMap({
  'symptoms': [
    {'key': key, 'label': key},
  ],
});

void main() {
  late MockCatalogRepository repository;
  late StreamController<SymptomCatalog?> published;
  late ProviderContainer container;
  late List<String?> seen;

  setUp(() {
    repository = MockCatalogRepository();
    published = StreamController<SymptomCatalog?>();
    when(() => repository.loadBundled()).thenAnswer((_) async => catalogOf('bundled'));
    when(() => repository.watchPublished()).thenAnswer((_) => published.stream);
    container = ProviderContainer.test(
      overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
    );
    seen = [];
    container.listen(
      symptomCatalogProvider,
      (previous, next) => seen.add(next.value?.symptoms.single.key),
      fireImmediately: true,
    );
  });

  tearDown(() => published.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('uses the bundled catalog until one is published', () async {
    await settle();
    published.add(null);
    await settle();

    expect(seen.last, 'bundled');
  });

  test('switches to the published catalog once it arrives', () async {
    await settle();
    published.add(catalogOf('published'));
    await settle();

    expect(seen, [null, 'bundled', 'published']);
  });

  test('keeps the catalog it has when the published one cannot be read', () async {
    await settle();
    published.add(catalogOf('published'));
    await settle();
    published.addError(StateError('permission denied'));
    await settle();

    expect(seen.last, 'published');
    expect(container.read(symptomCatalogProvider).hasError, isFalse);
  });
}
