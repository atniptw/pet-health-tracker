import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import 'create_household_screen.dart';
import 'household_providers.dart';
import 'join_household_screen.dart';

/// The open household's name. Tapping it opens a sheet to switch households,
/// join one, or create another.
class HouseholdTitle extends ConsumerWidget {
  const HouseholdTitle({required this.household, required this.uid, super.key});

  final Household household;

  /// The signed-in user.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final households = ref.watch(myHouseholdsProvider(uid)).value ?? const <Household>[];
    final name = Text(
      household.name,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      overflow: TextOverflow.ellipsis,
    );
    return Semantics(
      button: true,
      label: 'Switch household',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showSwitcher(context, ref, households),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: name),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  void _showSwitcher(BuildContext context, WidgetRef ref, List<Household> households) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final each in households)
                ListTile(
                  title: Text(each.name),
                  trailing: each.id == household.id ? const Icon(Icons.check) : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (each.id != household.id) {
                      unawaited(ref.read(lastHouseholdProvider(uid).notifier).select(each.id));
                    }
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Join a household'),
                onTap: () => _open(context, sheetContext, ref, JoinHouseholdScreen.new),
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create a household'),
                onTap: () => _open(context, sheetContext, ref, CreateHouseholdScreen.new),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Closes the sheet and opens [screen] for the signed-in user.
  void _open(
    BuildContext context,
    BuildContext sheetContext,
    WidgetRef ref,
    Widget Function({required User user}) screen,
  ) {
    Navigator.of(sheetContext).pop();
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    unawaited(
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => screen(user: user))),
    );
  }
}
