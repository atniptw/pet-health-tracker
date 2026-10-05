import 'package:flutter/material.dart';

import '../../data/household.dart';
import '../pets/pet_list.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.household, required this.uid, super.key});

  final Household household;

  /// The signed-in user.
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(household.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => SettingsScreen(household: household, uid: uid),
              ),
            ),
          ),
        ],
      ),
      body: PetList(householdId: household.id, canEdit: false),
    );
  }
}
