import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/household.dart';
import '../household/household_members.dart';
import '../household/household_providers.dart';

/// Everyone in the household, by name, with who is the owner or an admin
/// and which one is [uid].
class MembersScreen extends ConsumerWidget {
  const MembersScreen({required this.household, required this.uid, super.key});

  final Household household;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = watchHousehold(ref, this.household, uid);
    final names = ref.watch(memberNamesProvider(household.id)).value ?? const {};
    final members = sortedMembers(household, names);
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: ListView(
        children: [
          for (final member in members)
            ListTile(
              title: Text(member.name ?? noNameYet),
              subtitle: _labels(household, member.uid),
            ),
        ],
      ),
    );
  }

  Widget? _labels(Household household, String memberId) {
    final labels = [
      if (memberId == household.ownerId)
        'Owner'
      else if (household.adminIds.contains(memberId))
        'Admin',
      if (memberId == uid) 'You',
    ];
    return labels.isEmpty ? null : Text(labels.join(' · '));
  }
}
