import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../household/household_providers.dart';

/// Lets the owner, [uid], pick another member to become the household's
/// owner.
class TransferOwnershipScreen extends ConsumerWidget {
  const TransferOwnershipScreen({required this.household, required this.uid, super.key});

  final Household household;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(memberNamesProvider(household.id)).value ?? const {};
    final members = [
      for (final memberId in household.memberIds)
        if (memberId != uid) (uid: memberId, name: names[memberId]),
    ]..sort(byMemberName);
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer ownership')),
      body: ListView(
        children: [
          for (final member in members)
            ListTile(
              title: Text(member.name ?? 'No name yet'),
              onTap: () => _transfer(context, ref, member.uid, member.name ?? 'this member'),
            ),
        ],
      ),
    );
  }

  Future<void> _transfer(BuildContext context, WidgetRef ref, String toUid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make $name the owner?'),
        content: const Text(
          "They'll be able to delete the household or transfer it. You'll stay an admin.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Make owner'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Like renaming, transferring doesn't wait for the server.
    unawaited(
      ref
          .read(householdRepositoryProvider)
          .transferOwnership(householdId: household.id, toUid: toUid),
    );
    Navigator.of(context).pop();
  }
}

/// Named members by name, then members with no name yet.
int byMemberName(({String uid, String? name}) a, ({String uid, String? name}) b) {
  if (a.name == null || b.name == null) return a.name == null ? (b.name == null ? 0 : 1) : -1;
  return a.name!.toLowerCase().compareTo(b.name!.toLowerCase());
}
