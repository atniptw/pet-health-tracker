import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Typed codes must be at least this many characters; suggestions are too.
const minInviteCodeLength = 12;

/// An invite works for this long after it is made. The security rules use the
/// same 7 days.
const inviteLifetime = Duration(days: 7);

/// The code as it is matched: exactly as typed, without trailing spaces.
String normalizeInviteCode(String code) => code.trimRight();

/// Whether [code] is long enough to be an invite code.
bool isLongEnoughInviteCode(String code) =>
    normalizeInviteCode(code).runes.length >= minInviteCodeLength;

/// The invite's document ID for [code]: the SHA-256 hash of the code, in
/// lowercase hex. Firestore stores only this, never the code.
String inviteIdFor(String code) =>
    sha256.convert(utf8.encode(normalizeInviteCode(code))).toString();

const _wordsAsset = 'assets/invite/eff_short_wordlist_1.txt';
const _wordsLicenseAsset = 'assets/invite/eff_short_wordlist_1-LICENSE.txt';

/// Suggests invite codes of three random words, such as "acorn tulip shelf".
class InviteWords {
  InviteWords(this.words);

  final List<String> words;

  static Future<InviteWords> load(AssetBundle bundle) async {
    final text = await bundle.loadString(_wordsAsset);
    return InviteWords(LineSplitter.split(text).where((word) => word.isNotEmpty).toList());
  }

  /// Three random words, picked again until they are long enough.
  String suggest([Random? random]) {
    random ??= Random.secure();
    while (true) {
      final code = [for (var i = 0; i < 3; i++) words[random.nextInt(words.length)]].join(' ');
      if (isLongEnoughInviteCode(code)) return code;
    }
  }
}

/// Adds the word list's license to the app's license page.
void registerInviteWordsLicense() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(_wordsLicenseAsset);
    yield LicenseEntryWithLineBreaks(['EFF Short Wordlist 1'], license);
  });
}
