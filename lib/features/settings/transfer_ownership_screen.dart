import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../household/household_members.dart';
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
    final members = sortedMembers(household, names, except: uid);
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer ownership')),
      body: ListView(
        children: [
          for (final member in members)
            ListTile(
              title: Text(member.name ?? noNameYet),
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
