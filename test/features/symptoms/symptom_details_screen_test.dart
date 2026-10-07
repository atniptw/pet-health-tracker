import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/symptom_catalog.dart';
import 'package:pet_health_tracker/data/symptom_log.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';
import 'package:pet_health_tracker/features/symptoms/symptom_details_screen.dart';
import 'package:pet_health_tracker/features/symptoms/symptom_providers.dart';

import '../../helpers.dart';

class MockSymptomLogRepository extends Mock implements SymptomLogRepository {}

final catalog = SymptomCatalog.fromMap({
  'symptoms': [
    {
      'key': 'seizure',
      'label': 'Seizure',
      'questions': [
        {'key': 'durationSeconds', 'label': 'Duration', 'type': 'number', 'unit': 'seconds'},
        {
          'key': 'type',
          'label': 'Type',
          'type': 'singleChoice',
          'options': [
            {'key': 'focal', 'label': 'Focal'},
            {'key': 'generalized', 'label': 'Generalized'},
            {'key': 'notSure', 'label': 'Not sure'},
          ],
        },
        {'key': 'urinated', 'label': 'Urinated', 'type': 'yesNo'},
        {'key': 'foaming', 'label': 'Foaming or drooling', 'type': 'yesNo'},
        {'key': 'oldFlag', 'label': 'Old flag', 'type': 'yesNo', 'retired': true},
        {'key': 'oldNote', 'label': 'Old note', 'type': 'yesNo', 'retired': true},
      ],
    },
    {
      'key': 'vomit',
      'label': 'Vomit',
      'questions': [
        {
          'key': 'timing',
          'label': 'When',
          'type': 'singleChoice',
          'options': [
            {'key': 'rightAfterEating', 'label': 'Right after eating'},
            {'key': 'emptyStomach', 'label': 'Empty stomach'},
            {'key': 'grass', 'label': 'Grass', 'retired': true},
          ],
        },
        {
          'key': 'colours',
          'label': 'Colours',
          'type': 'multipleChoice',
          'options': [
            {'key': 'yellow', 'label': 'Yellow'},
            {'key': 'green', 'label': 'Green'},
          ],
        },
        {'key': 'smell', 'label': 'Smell', 'type': 'text'},
      ],
    },
  ],
});

void main() {
  late MockSymptomLogRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(DateTime(2026));
  });

  void stubAnswers(Future<void> Function() answer) {
    when(
      () => repository.updateAnswers(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        logId: any(named: 'logId'),
        answers: any(named: 'answers'),
      ),
    ).thenAnswer((_) => answer());
  }

  setUp(() {
    repository = MockSymptomLogRepository();
    stubAnswers(() async {});
    when(
      () => repository.updateNotes(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        logId: any(named: 'logId'),
        notes: any(named: 'notes'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repository.updateOccurredAt(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        logId: any(named: 'logId'),
        occurredAt: any(named: 'occurredAt'),
      ),
    ).thenAnswer((_) async {});
  });

  void verifyAnswers(Map<String, Object?> answers) {
    verify(
      () => repository.updateAnswers(householdId: 'h1', petId: 'p1', logId: 'l1', answers: answers),
    ).called(1);
  }

  void verifyNoWrites() {
    verifyNever(
      () => repository.updateAnswers(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        logId: any(named: 'logId'),
        answers: any(named: 'answers'),
      ),
    );
    verifyNever(
      () => repository.updateNotes(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        logId: any(named: 'logId'),
        notes: any(named: 'notes'),
      ),
    );
  }

  SymptomLog log({
    String symptom = 'seizure',
    Map<String, dynamic> answers = const {},
    String? notes,
  }) => SymptomLog(
    id: 'l1',
    symptom: symptom,
    createdBy: 'u1',
    occurredAt: DateTime(2026, 10, 6, 6, 40),
    answers: answers,
    notes: notes,
  );

  /// Pumps a button that opens the screen, so going back can be observed.
  Future<void> open(WidgetTester tester, SymptomLog log) async {
    await tester.pumpScoped(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => SymptomDetailsScreen(
                  householdId: 'h1',
                  petId: 'p1',
                  petName: 'Boogie',
                  log: log,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [
        symptomLogRepositoryProvider.overrideWithValue(repository),
        symptomCatalogProvider.overrideWith((ref) => Stream.value(catalog)),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, String key) =>
      tester.widget<Switch>(find.byKey(ValueKey(key))).value;

  Finder noteField() => find.byKey(const ValueKey('notes'));

  testWidgets('shows the symptom, the pet and when it happened', (tester) async {
    await open(tester, log());

    expect(find.text('Seizure'), findsOneWidget);
    expect(
      find.text('Boogie · Tuesday, October 6, 2026 · 6:40 AM', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets("shows each question with the log's answers", (tester) async {
    await open(
      tester,
      log(answers: {'durationSeconds': 47, 'type': 'generalized', 'urinated': true}),
    );

    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('47'), findsOneWidget);
    expect(find.text('seconds'), findsOneWidget);
    expect(tester.widget<SegmentedButton<String>>(find.byKey(const ValueKey('type'))).selected, {
      'generalized',
    });
    expect(switchValue(tester, 'urinated'), isTrue);
    expect(switchValue(tester, 'foaming'), isFalse);
    expect(find.text('Add a note'), findsOneWidget);
  });

  testWidgets('hides retired questions unless the log answers them', (tester) async {
    await open(tester, log(answers: {'oldNote': true}));

    expect(find.text('Old note'), findsOneWidget);
    expect(find.text('Old flag'), findsNothing);
  });

  testWidgets('switching a yes/no on stores true, and off removes it', (tester) async {
    await open(tester, log());

    await tapAndSettle(tester, find.byKey(const ValueKey('foaming')));
    verifyAnswers({'foaming': true});
    expect(switchValue(tester, 'foaming'), isTrue);

    await tapAndSettle(tester, find.text('Foaming or drooling'));
    verifyAnswers({'foaming': null});
    expect(switchValue(tester, 'foaming'), isFalse);
  });

  testWidgets('picking a choice stores it, and picking it again clears it', (tester) async {
    await open(tester, log());

    await tapAndSettle(tester, find.text('Focal'));
    verifyAnswers({'type': 'focal'});

    await tapAndSettle(tester, find.text('Focal'));
    verifyAnswers({'type': null});
  });

  testWidgets('choices with long labels are chips, and retired options are hidden', (tester) async {
    await open(tester, log(symptom: 'vomit'));

    expect(find.byKey(const ValueKey('timing')), findsNothing);
    expect(find.text('Grass'), findsNothing);
    await tapAndSettle(tester, find.widgetWithText(ChoiceChip, 'Empty stomach'));
    verifyAnswers({'timing': 'emptyStomach'});
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Empty stomach')).selected,
      isTrue,
    );
  });

  testWidgets('a retired option still shows when the log picked it', (tester) async {
    await open(tester, log(symptom: 'vomit', answers: {'timing': 'grass'}));

    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Grass')).selected, isTrue);
  });

  testWidgets('multiple choice stores the picked options', (tester) async {
    await open(tester, log(symptom: 'vomit'));

    await tapAndSettle(tester, find.text('Yellow'));
    verifyAnswers({
      'colours': ['yellow'],
    });
    await tapAndSettle(tester, find.text('Green'));
    verifyAnswers({
      'colours': ['yellow', 'green'],
    });
    await tapAndSettle(tester, find.text('Yellow'));
    verifyAnswers({
      'colours': ['green'],
    });
    await tapAndSettle(tester, find.text('Green'));
    verifyAnswers({'colours': null});
  });

  testWidgets('a number is stored on Done', (tester) async {
    await open(tester, log());

    await tester.enterText(find.byKey(const ValueKey('durationSeconds')), '90');
    await tapAndSettle(tester, find.text('Done'));

    verifyAnswers({'durationSeconds': 90});
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a cleared number is removed', (tester) async {
    await open(tester, log(answers: {'durationSeconds': 47}));

    await tester.enterText(find.byKey(const ValueKey('durationSeconds')), '');
    await tapAndSettle(tester, find.text('Done'));

    verifyAnswers({'durationSeconds': null});
  });

  testWidgets('a text answer is stored when moving to another field', (tester) async {
    await open(tester, log(symptom: 'vomit'));

    await tester.enterText(find.byKey(const ValueKey('smell')), ' Sour ');
    await tapAndSettle(tester, noteField());

    verifyAnswers({'smell': 'Sour'});
  });

  testWidgets('the note is saved on close', (tester) async {
    await open(tester, log());

    await tester.enterText(noteField(), 'Ate grass first ');
    await tapAndSettle(tester, find.byTooltip('Close'));

    verify(
      () => repository.updateNotes(
        householdId: 'h1',
        petId: 'p1',
        logId: 'l1',
        notes: 'Ate grass first',
      ),
    ).called(1);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a cleared note is removed', (tester) async {
    await open(tester, log(notes: 'Ate grass first'));

    expect(find.text('Ate grass first'), findsOneWidget);
    await tester.enterText(noteField(), '');
    await tapAndSettle(tester, find.text('Done'));

    verify(() => repository.updateNotes(householdId: 'h1', petId: 'p1', logId: 'l1', notes: ''))
        .called(1);
  });

  testWidgets('closing without changes writes nothing', (tester) async {
    await open(tester, log(answers: {'durationSeconds': 47}, notes: 'Ate grass first'));

    await tapAndSettle(tester, find.text('Done'));

    verifyNoWrites();
  });

  testWidgets('says so when a change cannot be saved', (tester) async {
    stubAnswers(() => Future.error('permission-denied'));
    await open(tester, log());

    await tapAndSettle(tester, find.byKey(const ValueKey('urinated')));

    expect(find.text("Couldn't save the log: permission-denied"), findsOneWidget);
  });

  testWidgets('a symptom missing from the catalog shows its key and the note', (tester) async {
    await open(tester, log(symptom: 'bloat'));

    expect(find.text('bloat'), findsOneWidget);
    expect(noteField(), findsOneWidget);
  });

  group('when it happened', () {
    const shown = 'Tuesday, October 6, 2026 · 6:40 AM';

    void verifyNoTimeWrite() => verifyNever(
      () => repository.updateOccurredAt(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        logId: any(named: 'logId'),
        occurredAt: any(named: 'occurredAt'),
      ),
    );

    testWidgets('shows when the log happened', (tester) async {
      await open(tester, log());

      expect(find.text('Occurred'), findsOneWidget);
      expect(find.text(shown), findsOneWidget);
    });

    testWidgets('writes only the new time when another date is picked', (tester) async {
      await open(tester, log());
      await tapAndSettle(tester, find.byKey(const ValueKey('occurredAt')));
      await tester.tap(find.text('5'));
      await tapAndSettle(tester, find.text('OK'));
      await tapAndSettle(tester, find.text('OK'));

      verify(
        () => repository.updateOccurredAt(
          householdId: 'h1',
          petId: 'p1',
          logId: 'l1',
          occurredAt: DateTime(2026, 10, 5, 6, 40),
        ),
      ).called(1);
      expect(find.text('Monday, October 5, 2026 · 6:40 AM'), findsOneWidget);
      expect(find.textContaining('Monday, October 5, 2026', findRichText: true), findsNWidgets(2));
      verifyNoWrites();
    });

    testWidgets('writes nothing when the pickers are cancelled', (tester) async {
      await open(tester, log());
      await tapAndSettle(tester, find.byKey(const ValueKey('occurredAt')));
      await tapAndSettle(tester, find.text('Cancel'));

      expect(find.text(shown), findsOneWidget);
      verifyNoTimeWrite();
    });

    testWidgets('writes nothing when the same time is picked', (tester) async {
      await open(tester, log());
      await tapAndSettle(tester, find.byKey(const ValueKey('occurredAt')));
      await tapAndSettle(tester, find.text('OK'));
      await tapAndSettle(tester, find.text('OK'));

      verifyNoTimeWrite();
    });
  });
}
