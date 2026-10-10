import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/invite.dart';
import 'package:pet_health_tracker/data/invite_code.dart';
import 'package:pet_health_tracker/data/invite_repository.dart';
import 'package:pet_health_tracker/features/household/invite_providers.dart';
import 'package:pet_health_tracker/features/household/invite_screen.dart';

import '../helpers.dart';

class MockInviteRepository extends Mock implements InviteRepository {}

void main() {
  const household = Household(id: 'h1', name: 'The Den', memberIds: ['u1'], adminIds: ['u1']);
  final words = InviteWords(['acorn', 'tulip', 'shelf']);

  late FakeFirebaseFirestore firestore;
  late FakeInviteCodeStore store;
  late List<String> shared;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    store = FakeInviteCodeStore();
    shared = [];
  });

  Future<void> pumpInvite(WidgetTester tester, {InviteRepository? repository}) async {
    await tester.pumpScoped(
      const InviteScreen(household: household, uid: 'u1'),
      overrides: [
        inviteRepositoryProvider.overrideWithValue(repository ?? InviteRepository(firestore)),
        inviteCodeStoreProvider.overrideWithValue(store),
        inviteWordsProvider.overrideWith((ref) async => words),
        shareTextProvider.overrideWithValue((text, origin) async => shared.add(text)),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedInvite(String code, {DateTime? createdAt}) {
    return firestore.doc('invites/${inviteIdFor(code)}').set({
      'householdId': 'h1',
      'createdBy': 'u2',
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      'schemaVersion': 1,
    });
  }

  final codeField = find.widgetWithText(TextField, 'Invite code');
  String fieldText(WidgetTester tester) => tester.widget<TextField>(codeField).controller!.text;

  testWidgets('with no code, suggests three words to make one from', (tester) async {
    await pumpInvite(tester);

    expect(fieldText(tester).split(' '), hasLength(3));
    expect(fieldText(tester).split(' '), everyElement(isIn(words.words)));
    expect(find.text('Create code'), findsOneWidget);
  });

  testWidgets('the code field has autocorrect and suggestions off', (tester) async {
    await pumpInvite(tester);

    final field = tester.widget<TextField>(codeField);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
  });

  testWidgets('suggests another code on tap', (tester) async {
    await pumpInvite(tester);
    await tester.enterText(codeField, 'something else entirely');

    await tester.tap(find.byTooltip('Suggest another'));
    await tester.pumpAndSettle();

    expect(fieldText(tester).split(' '), everyElement(isIn(words.words)));
  });

  testWidgets('refuses a code under 12 characters', (tester) async {
    await pumpInvite(tester);
    await tester.enterText(codeField, 'short code ');
    await tester.tap(find.text('Create code'));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 12 characters.'), findsOneWidget);
    expect((await firestore.collection('invites').get()).docs, isEmpty);
    expect(store.saved, isEmpty);
  });

  testWidgets('makes a typed code, saves it on the phone, and shows it', (tester) async {
    await pumpInvite(tester);
    await tester.enterText(codeField, 'Our Den #1 2026  ');
    await tester.tap(find.text('Create code'));
    await tester.pumpAndSettle();

    expect(store.saved['u1.h1'], 'Our Den #1 2026');
    final invites = (await firestore.collection('invites').get()).docs;
    expect(invites.single.id, inviteIdFor('Our Den #1 2026'));
    expect(find.text('Our Den #1 2026'), findsOneWidget);
    expect(find.textContaining('Anyone with this code can join as a member until'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('shares the code with the household name', (tester) async {
    await pumpInvite(tester);
    await tester.enterText(codeField, 'acorn tulip shelf');
    await tester.tap(find.text('Create code'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(shared, [
      'Join "The Den" in Pet Health Tracker with this invite code: acorn tulip shelf',
    ]);
  });

  testWidgets('shows when a code made on this phone expires', (tester) async {
    await seedInvite('acorn tulip shelf', createdAt: DateTime(2026, 10, 9, 14, 30));
    store.saved['u1.h1'] = 'acorn tulip shelf';
    final repository = MockInviteRepository();
    when(() => repository.watchActiveInvite('h1')).thenAnswer(
      (_) => Stream.value(
        Invite(
          id: inviteIdFor('acorn tulip shelf'),
          householdId: 'h1',
          createdAt: DateTime(2026, 10, 9, 14, 30),
        ),
      ),
    );

    await pumpInvite(tester, repository: repository);

    expect(find.text('acorn tulip shelf'), findsOneWidget);
    expect(
      find.text('Anyone with this code can join as a member until Fri, Oct 16 at 2:30 PM.'),
      findsOneWidget,
    );
  });

  testWidgets('a code made on another phone shows only that one is active', (tester) async {
    await seedInvite('acorn tulip shelf');

    await pumpInvite(tester);

    expect(find.textContaining('It was made on another phone'), findsOneWidget);
    expect(find.text('acorn tulip shelf'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Make a new code'), findsOneWidget);
  });

  testWidgets('forgets a saved code that was replaced', (tester) async {
    await seedInvite('plum otter lamp');
    store.saved['u1.h1'] = 'acorn tulip shelf';

    await pumpInvite(tester);

    expect(store.saved, isEmpty);
    expect(find.textContaining('It was made on another phone'), findsOneWidget);
  });

  testWidgets('forgets a saved code that expired', (tester) async {
    await seedInvite('acorn tulip shelf', createdAt: DateTime.now().subtract(inviteLifetime));
    store.saved['u1.h1'] = 'acorn tulip shelf';

    await pumpInvite(tester);

    expect(store.saved, isEmpty);
    expect(find.text('Create code'), findsOneWidget);
  });

  testWidgets('making a new code warns, and can be cancelled', (tester) async {
    await seedInvite('acorn tulip shelf');
    store.saved['u1.h1'] = 'acorn tulip shelf';
    await pumpInvite(tester);

    await tester.tap(find.text('Make a new code'));
    await tester.pumpAndSettle();
    expect(find.text('Your current code will stop working.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('acorn tulip shelf'), findsOneWidget);
  });

  testWidgets('a new code replaces the old one', (tester) async {
    await seedInvite('acorn tulip shelf');
    store.saved['u1.h1'] = 'acorn tulip shelf';
    await pumpInvite(tester);

    await tester.tap(find.text('Make a new code'));
    await tester.pumpAndSettle();
    await tester.enterText(codeField, 'plum otter lamp');
    await tester.tap(find.text('Create code'));
    await tester.pumpAndSettle();

    expect(find.text('plum otter lamp'), findsOneWidget);
    expect(store.saved['u1.h1'], 'plum otter lamp');
    final ids = (await firestore.collection('invites').get()).docs.map((d) => d.id);
    expect(ids, [inviteIdFor('plum otter lamp')]);
  });

  testWidgets('shows a spinner while creating', (tester) async {
    final repository = MockInviteRepository();
    final completer = Completer<void>();
    when(() => repository.watchActiveInvite('h1')).thenAnswer((_) => Stream.value(null));
    when(
      () => repository.createInvite(
        householdId: any(named: 'householdId'),
        createdBy: any(named: 'createdBy'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) => completer.future);

    await pumpInvite(tester, repository: repository);
    await tester.tap(find.text('Create code'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Create code'), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('says when a code is taken', (tester) async {
    final repository = MockInviteRepository();
    when(() => repository.watchActiveInvite('h1')).thenAnswer((_) => Stream.value(null));
    when(
      () => repository.createInvite(
        householdId: any(named: 'householdId'),
        createdBy: any(named: 'createdBy'),
        code: any(named: 'code'),
      ),
    ).thenThrow(const InviteCodeTakenException());

    await pumpInvite(tester, repository: repository);
    await tester.enterText(codeField, 'acorn tulip shelf');
    await tester.tap(find.text('Create code'));
    await tester.pumpAndSettle();

    expect(find.text('That code is taken. Try another.'), findsOneWidget);
  });

  testWidgets('shows the error when the invite fails to load and retries on tap', (tester) async {
    final repository = MockInviteRepository();
    when(() => repository.watchActiveInvite('h1')).thenAnswer((_) => Stream.error('offline'));

    await pumpInvite(tester, repository: repository);
    expect(find.text('offline'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    verify(() => repository.watchActiveInvite('h1')).called(2);
  });
}
