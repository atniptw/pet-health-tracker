import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('of finds the repositories', (tester) async {
    final app = (await tester.runAsync(openTestApp))!;
    late AppScope found;

    await tester.pumpWidget(
      app.wrap(
        Builder(
          builder: (context) {
            found = AppScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(found.pets, same(app.pets));
    expect(found.eventTypes, same(app.eventTypes));
    expect(found.events, same(app.events));
  });

  testWidgets('of with no AppScope above fails', (tester) async {
    late Object error;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          try {
            AppScope.of(context);
          } catch (e) {
            error = e;
          }
          return const SizedBox();
        },
      ),
    );

    expect(error, isA<AssertionError>());
  });

  test('updateShouldNotify is true only when a repository changes', () async {
    final first = await openTestApp();
    final second = await openTestApp();
    AppScope scope({required bool pets, required bool eventTypes, required bool events}) =>
        AppScope(
          pets: pets ? second.pets : first.pets,
          eventTypes: eventTypes ? second.eventTypes : first.eventTypes,
          events: events ? second.events : first.events,
          child: const SizedBox(),
        );
    final same = scope(pets: false, eventTypes: false, events: false);

    expect(scope(pets: false, eventTypes: false, events: false).updateShouldNotify(same), isFalse);
    expect(scope(pets: true, eventTypes: false, events: false).updateShouldNotify(same), isTrue);
    expect(scope(pets: false, eventTypes: true, events: false).updateShouldNotify(same), isTrue);
    expect(scope(pets: false, eventTypes: false, events: true).updateShouldNotify(same), isTrue);
  });
}
