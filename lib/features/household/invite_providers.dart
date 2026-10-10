import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/firebase_providers.dart';
import '../../data/invite.dart';
import '../../data/invite_code.dart';
import '../../data/invite_code_store.dart';
import '../../data/invite_repository.dart';

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepository(ref.watch(firestoreProvider));
});

final inviteCodeStoreProvider = Provider<InviteCodeStore>((ref) {
  return InviteCodeStore(const FlutterSecureStorage());
});

final inviteWordsProvider = FutureProvider<InviteWords>((ref) => InviteWords.load(rootBundle));

/// Opens the share sheet with [text], anchored at [origin] on iPad.
typedef ShareText = Future<void> Function(String text, Rect? origin);

final shareTextProvider = Provider<ShareText>((ref) {
  return (text, origin) async {
    await SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
  };
});

/// The household's active invite, and its code if this phone made it.
typedef InviteState = ({Invite? invite, String? code});

/// A saved code that no longer matches the active invite, because it expired
/// or another code replaced it, is deleted from the phone.
final inviteStateProvider = StreamProvider.autoDispose
    .family<InviteState, ({String householdId, String uid})>((ref, key) async* {
      final store = ref.watch(inviteCodeStoreProvider);
      final invites = ref.watch(inviteRepositoryProvider).watchActiveInvite(key.householdId);
      await for (final invite in invites) {
        final saved = await store.read(uid: key.uid, householdId: key.householdId);
        final code = savedCodeFor(invite, saved);
        if (saved != null && code == null) {
          await store.deleteIfStill(uid: key.uid, householdId: key.householdId, code: saved);
        }
        yield (invite: invite, code: code);
      }
    });
