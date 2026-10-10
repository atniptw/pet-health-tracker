import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/household.dart';
import 'household_providers.dart';

/// The open household's name. When the user is in more than one household,
/// tapping it opens a sheet to switch.
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
    if (households.length < 2) return name;

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
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final each in households)
                ListTile(
                  title: Text(each.name),
                  trailing: each.id == household.id ? const Icon(Icons.check) : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (each.id != household.id) {
                      unawaited(ref.read(lastHouseholdProvider(uid).notifier).select(each.id));
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
