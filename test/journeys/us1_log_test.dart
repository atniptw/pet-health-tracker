import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app.dart';
import 'package:pet_health_tracker/domain/pet.dart';

import '../support/robot.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('001-US1-S1 001-FR-014: signed out, add Rex, then log Vomiting now, a 2-minute '
      'Seizure yesterday and "Ear shaking" in the caregiver\'s own words', (tester) async {
    final app = await openTestApp(now: DateTime(2026, 11, 14, 12));
    final robot = Robot(tester);
    await tester.pumpWidget(
      App(pets: app.pets, eventTypes: app.eventTypes, events: app.events, clock: app.clock),
    );
    await tester.pumpAndSettle();

    await robot.addPet('Rex', Species.dog);

    await robot.logEvent('Vomiting');
    expect(find.text('Saved: Vomiting for Rex'), findsOneWidget);

    await robot.logEvent('Seizure', at: DateTime(2026, 11, 13, 21, 30), minutes: 2);
    expect(find.text('Saved: Seizure for Rex'), findsOneWidget);

    await robot.logSomethingElse('Ear shaking');
    expect(find.text('Saved: Ear shaking for Rex'), findsOneWidget);

    final rex = (await tester.runAsync(() => app.pets.watchActive().first))!.single;
    final events = (await tester.runAsync(() => app.events.watchForPet(rex.id).first))!;
    final custom = (await tester.runAsync(() => app.eventTypes.watchCustom().first))!;
    expect(custom.map((type) => type.name), ['Ear shaking']);
    expect(
      {for (final event in events) event.typeId: (event.occurredAt, event.details['duration'])},
      {
        'vomiting': (DateTime(2026, 11, 14, 12).toUtc(), null),
        'seizure': (DateTime(2026, 11, 13, 21, 30).toUtc(), 120),
        custom.single.id: (DateTime(2026, 11, 14, 12).toUtc(), null),
      },
    );
  });
}
