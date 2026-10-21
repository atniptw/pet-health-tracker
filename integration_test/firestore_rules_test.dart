import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/data/invite_code.dart';
import 'package:pet_health_tracker/data/invite_repository.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';
import 'package:pet_health_tracker/firebase_options.dart';

/// Runs the app's repositories against the Firebase emulators, so their writes
/// are checked by the real security rules. Widget and unit tests use a fake
/// Firestore that has no rules.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
  // Each run signs up its own users, so a rerun against the same emulators works.
  final run = DateTime.now().microsecondsSinceEpoch;
  late FirebaseFirestore firestore;
  late HouseholdRepository households;

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    firestore = FirebaseFirestore.instance..useFirestoreEmulator(host, 8080);
    households = HouseholdRepository(firestore);
  });

  /// Signs in as the test user called [name], signing them up the first time,
  /// and returns their uid.
  Future<String> signInAs(String name) async {
    final auth = FirebaseAuth.instance;
    final email = '$name-$run@example.com';
    const password = 'password';
    await auth.signOut();
    try {
      return (await auth.signInWithEmailAndPassword(email: email, password: password)).user!.uid;
    } on FirebaseAuthException {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!.uid;
    }
  }

  /// Whether the document at [path] exists, read past the rules.
  Future<bool> exists(String path) async {
    final projectId = Firebase.app().options.projectId;
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://$host:8080/v1/projects/$projectId/databases/(default)/documents/$path'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode == 404) return false;
      if (response.statusCode == 200) return true;
      throw StateError('Reading $path: HTTP ${response.statusCode}');
    } finally {
      client.close();
    }
  }

  /// [owner]'s household named [name], with a pet and an invite that
  /// [member] joined with. Leaves [member] signed in.
  Future<({String householdId, String petId, String inviteCode, String ownerUid, String memberUid})>
  householdWithPet(String name, {required String owner, required String member}) async {
    final ownerUid = await signInAs(owner);
    final householdId = await households.createHousehold(
      name: name,
      ownerUid: ownerUid,
      ownerName: owner,
    );
    await PetRepository(firestore)
        .addPet(householdId: householdId, name: 'Boogie', species: Species.dog);
    final pets = await firestore.collection('households/$householdId/pets').get();
    final inviteCode = 'code $name $run';
    await InviteRepository(firestore)
        .createInvite(householdId: householdId, createdBy: ownerUid, code: inviteCode);
    final memberUid = await signInAs(member);
    await households.joinHousehold(code: inviteCode, uid: memberUid, name: member);
    return (
      householdId: householdId,
      petId: pets.docs.single.id,
      inviteCode: inviteCode,
      ownerUid: ownerUid,
      memberUid: memberUid,
    );
  }

  Future<void> logSymptom(String householdId, String petId, String logId, String uid) {
    return SymptomLogRepository(firestore).addOtherLog(
      householdId: householdId,
      petId: petId,
      createdBy: uid,
      title: 'Sneezing',
      occurredAt: DateTime(2026, 10, 20),
      logId: logId,
    );
  }

  Matcher deniedPermission() =>
      isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied');

  testWidgets('the owner deletes a household and everything in it', (tester) async {
    final h = await householdWithPet('Delete', owner: 'ann', member: 'bob');
    final (ann, bob) = (h.ownerUid, h.memberUid);
    await logSymptom(h.householdId, h.petId, 'bobs-log', bob);
    await signInAs('ann');
    await logSymptom(h.householdId, h.petId, 'anns-log', ann);
    final household = 'households/${h.householdId}';
    final paths = [
      household,
      '$household/members/$ann',
      '$household/members/$bob',
      '$household/pets/${h.petId}',
      '$household/pets/${h.petId}/symptomLogs/bobs-log',
      '$household/pets/${h.petId}/symptomLogs/anns-log',
      'invites/${inviteIdFor(h.inviteCode)}',
    ];
    for (final path in paths) {
      expect(await exists(path), isTrue, reason: path);
    }

    await households.deleteHousehold(h.householdId);

    for (final path in paths) {
      expect(await exists(path), isFalse, reason: path);
    }
  });

  testWidgets('only the owner can delete a household', (tester) async {
    final h = await householdWithPet('Keep', owner: 'cat', member: 'dan');

    await expectLater(households.deleteHousehold(h.householdId), throwsA(deniedPermission()));

    expect(await exists('households/${h.householdId}'), isTrue);
  });

  testWidgets('a member who leaves loses their name, and their logs stay', (tester) async {
    final h = await householdWithPet('Leave', owner: 'eve', member: 'fay');
    final fay = h.memberUid;
    await logSymptom(h.householdId, h.petId, 'fays-log', fay);

    await households.leaveHousehold(householdId: h.householdId, uid: fay);

    final household = 'households/${h.householdId}';
    expect(await exists('$household/members/$fay'), isFalse);
    expect(await exists('$household/pets/${h.petId}/symptomLogs/fays-log'), isTrue);
    await signInAs('eve');
    final members = await households.watchMemberNames(h.householdId).first;
    expect(members.values, ['eve']);
  });

  testWidgets('after a transfer, the new owner can delete and the old one cannot', (tester) async {
    final h = await householdWithPet('Transfer', owner: 'gus', member: 'hal');
    await signInAs('gus');

    await households.transferOwnership(householdId: h.householdId, toUid: h.memberUid);

    await expectLater(households.deleteHousehold(h.householdId), throwsA(deniedPermission()));
    await signInAs('hal');
    await households.deleteHousehold(h.householdId);
    expect(await exists('households/${h.householdId}'), isFalse);
  });
}
