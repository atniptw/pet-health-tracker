import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/features/auth/account_deletion.dart';
import 'package:pet_health_tracker/features/settings/delete_account_screen.dart';

import '../../helpers.dart';

class MockAccountDeletion extends Mock implements AccountDeletion {}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockAccountDeletion deletion;

  Future<void> household(
    String id, {
    required String owner,
    List<String> others = const [],
    Map<String, String> names = const {},
  }) async {
    await firestore.doc('households/$id').set({
      'name': id,
      'memberIds': [owner, ...others],
      'adminIds': [owner],
      'ownerId': owner,
    });
    for (final MapEntry(key: uid, value: name) in names.entries) {
      await firestore.doc('households/$id/members/$uid').set({'name': name});
    }
  }

  setUpAll(() => registerFallbackValue(<String, String?>{}));

  setUp(() {
    firestore = FakeFirebaseFirestore();
    deletion = MockAccountDeletion();
    when(
      () => deletion.delete(
        uid: any(named: 'uid'),
        newOwners: any(named: 'newOwners'),
      ),
    ).thenAnswer((_) async {});
  });

  /// Opens the screen on top of a placeholder root, as settings does.
  Future<void> open(WidgetTester tester) async {
    await tester.pumpScoped(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const DeleteAccountScreen(uid: 'me')),
          ),
          child: const Text('open'),
        ),
      ),
      overrides: [
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(firestore)),
        accountDeletionProvider.overrideWithValue(deletion),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder deleteButton() => find.widgetWithText(FilledButton, 'Delete account');

  bool enabled(WidgetTester tester) => tester.widget<FilledButton>(deleteButton()).enabled;

  Future<void> deleteAndConfirm(WidgetTester tester) async {
    await tester.ensureVisible(deleteButton());
    await tester.tap(deleteButton());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete account'));
  }

  testWidgets('says what happens, and which households the user leaves', (tester) async {
    await household('The Burrow', owner: 'you', others: ['me']);
    await household('The Den', owner: 'pat', others: ['me']);

    await open(tester);

    expect(find.textContaining('show "Former member"'), findsOneWidget);
    expect(find.text("You'll leave"), findsOneWidget);
    expect(find.text('The Burrow, The Den'), findsOneWidget);
    expect(enabled(tester), isTrue);
  });

  testWidgets('a household the user owns needs a choice first', (tester) async {
    await household(
      'The Den',
      owner: 'me',
      others: ['sam', 'nameless'],
      names: {'me': 'Tom', 'sam': 'Sam'},
    );

    await open(tester);

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('No name yet'), findsOneWidget);
    expect(find.text('Delete The Den'), findsOneWidget);
    expect(enabled(tester), isFalse);
    expect(find.text('Choose what happens to each household you own.'), findsOneWidget);
  });

  testWidgets('hands an owned household to the member picked', (tester) async {
    await household('The Den', owner: 'me', others: ['sam'], names: {'sam': 'Sam'});
    await open(tester);

    await tester.tap(find.text('Sam'));
    await tester.pump();
    await deleteAndConfirm(tester);
    await tester.pumpAndSettle();

    verify(() => deletion.delete(uid: 'me', newOwners: {'The Den': 'sam'})).called(1);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('deletes an owned household when picked', (tester) async {
    await household('The Den', owner: 'me', others: ['sam'], names: {'sam': 'Sam'});
    await open(tester);

    await tester.tap(find.text('Delete The Den'));
    await tester.pump();
    await deleteAndConfirm(tester);
    await tester.pumpAndSettle();

    verify(() => deletion.delete(uid: 'me', newOwners: {'The Den': null})).called(1);
  });

  testWidgets('a household with no one else in it can only be deleted', (tester) async {
    await household('The Den', owner: 'me');
    await open(tester);

    expect(find.textContaining('No one else is in it'), findsOneWidget);
    expect(enabled(tester), isTrue);
    await deleteAndConfirm(tester);
    await tester.pumpAndSettle();

    verify(() => deletion.delete(uid: 'me', newOwners: {'The Den': null})).called(1);
  });

  testWidgets('a picked member who leaves needs a new choice', (tester) async {
    await household('The Den', owner: 'me', others: ['sam', 'kit'], names: {'sam': 'Sam'});
    await open(tester);
    await tester.tap(find.text('Sam'));
    await tester.pump();
    expect(enabled(tester), isTrue);

    await firestore.doc('households/The Den').update({
      'memberIds': ['me', 'kit'],
    });
    await tester.pumpAndSettle();

    expect(enabled(tester), isFalse);
  });

  testWidgets('cancelling deletes nothing', (tester) async {
    await household('The Den', owner: 'pat', others: ['me']);
    await open(tester);

    await tester.tap(deleteButton());
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => deletion.delete(
        uid: any(named: 'uid'),
        newOwners: any(named: 'newOwners'),
      ),
    );
  });

  testWidgets('waits for the deletion, showing progress', (tester) async {
    final deleted = Completer<void>();
    when(
      () => deletion.delete(
        uid: any(named: 'uid'),
        newOwners: any(named: 'newOwners'),
      ),
    ).thenAnswer((_) => deleted.future);
    await household('The Den', owner: 'pat', others: ['me']);
    await open(tester);

    await deleteAndConfirm(tester);
    await tester.pump();
    expect(find.text('Deleting your account…'), findsOneWidget);

    deleted.complete();
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsNothing);
  });

  testWidgets('cancelling the Google sign-in stays put, with no message', (tester) async {
    when(
      () => deletion.delete(
        uid: any(named: 'uid'),
        newOwners: any(named: 'newOwners'),
      ),
    ).thenThrow(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled));
    await household('The Den', owner: 'pat', others: ['me']);
    await open(tester);

    await deleteAndConfirm(tester);
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(find.text('Deleting your account…'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('says why when the account cannot be deleted', (tester) async {
    when(
      () => deletion.delete(
        uid: any(named: 'uid'),
        newOwners: any(named: 'newOwners'),
      ),
    ).thenThrow(const OwnedHouseholdsChangedException());
    await household('The Den', owner: 'pat', others: ['me']);
    await open(tester);

    await deleteAndConfirm(tester);
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(
      find.text("Couldn't delete your account: Your households changed. Check them and try again."),
      findsOneWidget,
    );
  });
}
