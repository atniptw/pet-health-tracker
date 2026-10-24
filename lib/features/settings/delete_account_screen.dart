import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/household.dart';
import '../auth/account_deletion.dart';
import '../household/household_members.dart';
import '../household/household_providers.dart';

/// What happens to a household the user owns: handed to [newOwner], or
/// deleted when it's null.
typedef _Choice = ({String? newOwner});

/// Deletes [uid]'s account, after they choose, for each household they own,
/// who owns it next or whether to delete it.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({required this.uid, super.key});

  final String uid;

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _choices = <String, _Choice>{};

  /// The choice for [household], if one was made and still holds. A
  /// household with no one else in it can only be deleted.
  _Choice? _choiceFor(Household household) {
    if (household.memberIds.length == 1) return (newOwner: null);
    final choice = _choices[household.id];
    final newOwner = choice?.newOwner;
    if (newOwner != null && !household.memberIds.contains(newOwner)) return null;
    return choice;
  }

  @override
  Widget build(BuildContext context) {
    final households = ref.watch(myHouseholdsProvider(widget.uid)).value;
    if (households == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delete account')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final owned = households.where((h) => h.ownerId == widget.uid).toList();
    final leaving = households.where((h) => h.ownerId != widget.uid).toList();
    final ready = owned.every((h) => _choiceFor(h) != null);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Your name is removed from every household you're in. The symptoms you "
              'logged stay, and show "Former member". This can\'t be undone.',
            ),
          ),
          for (final household in owned)
            _OwnedHousehold(
              household: household,
              uid: widget.uid,
              choice: _choiceFor(household),
              onChanged: (choice) => setState(() => _choices[household.id] = choice),
            ),
          if (leaving.isNotEmpty)
            ListTile(
              title: Text("You'll leave", style: textTheme.titleSmall),
              subtitle: Text(leaving.map((h) => h.name).join(', ')),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: ready ? () => _delete(owned) : null,
              child: const Text('Delete account'),
            ),
          ),
          if (!ready)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Choose what happens to each household you own.',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _delete(List<Household> owned) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text("You'll sign in once more to confirm it's you."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final newOwners = {for (final h in owned) h.id: _choiceFor(h)!.newOwner};
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final deletion = ref.read(accountDeletionProvider);
    // Like deleting a household, this waits for the server.
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 24),
                Expanded(child: Text('Deleting your account…')),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await deletion.delete(uid: widget.uid, newOwners: newOwners);
      // Back to the root, which shows sign-in now no one is signed in.
      navigator.popUntil((route) => route.isFirst);
    } on GoogleSignInException catch (e) {
      navigator.pop();
      if (e.code != GoogleSignInExceptionCode.canceled) _failed(messenger, e);
    } catch (e) {
      navigator.pop();
      _failed(messenger, e);
    }
  }

  void _failed(ScaffoldMessengerState messenger, Object e) {
    messenger.showSnackBar(SnackBar(content: Text("Couldn't delete your account: $e")));
  }
}

/// The choice for one household the user owns: one of its other members, or
/// deleting it.
class _OwnedHousehold extends ConsumerWidget {
  const _OwnedHousehold({
    required this.household,
    required this.uid,
    required this.choice,
    required this.onChanged,
  });

  final Household household;
  final String uid;
  final _Choice? choice;
  final ValueChanged<_Choice> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(memberNamesProvider(household.id)).value ?? const {};
    final members = sortedMembers(household, names, except: uid);
    return RadioGroup<_Choice>(
      groupValue: choice,
      onChanged: (choice) => onChanged(choice!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(household.name, style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text(
              members.isEmpty
                  ? "You own it. No one else is in it, so it's deleted with its pets and logs."
                  : 'You own it. Choose who owns it next, or delete it.',
            ),
          ),
          for (final member in members)
            RadioListTile<_Choice>(
              value: (newOwner: member.uid),
              title: Text(member.name ?? noNameYet),
              subtitle: const Text('Becomes the owner'),
            ),
          RadioListTile<_Choice>(
            value: (newOwner: null),
            title: Text('Delete ${household.name}'),
            subtitle: const Text('With its pets and logs, for everyone in it'),
          ),
        ],
      ),
    );
  }
}
