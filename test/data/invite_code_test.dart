import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/invite_code.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('inviteIdFor', () {
    test('is the SHA-256 hash of the code in lowercase hex', () {
      expect(
        inviteIdFor('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('ignores trailing spaces only', () {
      expect(inviteIdFor('acorn tulip shelf  '), inviteIdFor('acorn tulip shelf'));
      expect(inviteIdFor(' acorn tulip shelf'), isNot(inviteIdFor('acorn tulip shelf')));
    });

    test('is case sensitive, so codes match exactly', () {
      expect(inviteIdFor('Acorn tulip shelf'), isNot(inviteIdFor('acorn tulip shelf')));
    });
  });

  group('isLongEnoughInviteCode', () {
    test('needs 12 characters, not counting trailing spaces', () {
      expect(isLongEnoughInviteCode('x' * 12), isTrue);
      expect(isLongEnoughInviteCode('x' * 11), isFalse);
      expect(isLongEnoughInviteCode('${'x' * 11}   '), isFalse);
    });

    test('counts any characters', () {
      expect(isLongEnoughInviteCode('🐶🐱!@#\$%^&*()'), isTrue);
    });
  });

  group('InviteWords', () {
    test('loads the bundled word list', () async {
      final words = await InviteWords.load(rootBundle);

      expect(words.words, hasLength(1296));
      expect(words.words, everyElement(matches(RegExp(r'^[a-z][a-z-]*$'))));
      expect(words.words.toSet(), hasLength(1296));
    });

    test('suggests three words separated by spaces', () {
      final code = InviteWords(['acorn', 'tulip', 'shelf']).suggest(Random(1));

      expect(code.split(' '), hasLength(3));
      expect(code.split(' '), everyElement(isIn(['acorn', 'tulip', 'shelf'])));
    });

    test('picks again until the suggestion is long enough', () {
      // "ox ox ox" is 8 characters; only a long word gets past.
      final words = InviteWords(['ox', 'ox', 'ox', 'elephant']);

      for (var seed = 0; seed < 20; seed++) {
        expect(isLongEnoughInviteCode(words.suggest(Random(seed))), isTrue);
      }
    });

    test('suggests different codes', () {
      final words = InviteWords(['acorn', 'tulip', 'shelf', 'otter', 'lamp', 'plum']);
      final random = Random(7);

      expect({for (var i = 0; i < 20; i++) words.suggest(random)}.length, greaterThan(1));
    });

    test('uses a secure random source by default', () {
      expect(isLongEnoughInviteCode(InviteWords(['acorn', 'tulip']).suggest()), isTrue);
    });
  });

  test("the word list's license is registered", () async {
    registerInviteWordsLicense();

    final licenses = await LicenseRegistry.licenses.toList();
    final license = licenses.where((l) => l.packages.contains('EFF Short Wordlist 1'));
    expect(license, isNotEmpty);
    expect(
      license.first.paragraphs.map((paragraph) => paragraph.text).join('\n'),
      contains('Creative Commons Attribution 3.0'),
    );
  });
}
