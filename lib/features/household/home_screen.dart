import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/household.dart';
import '../../data/pet.dart';
import '../../data/symptom_log.dart';
import '../pets/all_pets_screen.dart';
import '../pets/pet_avatar.dart';
import '../pets/pet_form_screen.dart';
import '../pets/pet_list.dart';
import '../pets/pet_providers.dart';
import '../settings/settings_screen.dart';
import '../symptoms/log_summary.dart';
import '../symptoms/pet_logs_screen.dart';
import '../symptoms/symptom_providers.dart';

/// Up to this many pets show as a grid of cards; more as a row of avatars.
const _gridMaxPets = 4;

/// How many logs the "Recent" list shows.
const _recentCount = 5;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.household, required this.uid, super.key});

  final Household household;

  /// The signed-in user.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsState = ref.watch(petsProvider(household.id));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 20,
        title: Text(
          household.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => SettingsScreen(household: household, uid: uid),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: petsState.when(
        data: (pets) => pets.isEmpty ? _NoPets(household: household, uid: uid) : _pets(pets),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(petsProvider(household.id)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pets(List<Pet> pets) {
    final grid = pets.length <= _gridMaxPets;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (grid)
          _PetGrid(household: household, uid: uid, pets: pets)
        else
          _PetRow(household: household, uid: uid, pets: pets),
        _Recent(household: household, uid: uid, pets: pets, showAllPets: !grid),
      ],
    );
  }
}

/// What a household with no pets sees. Only admins can add one.
class _NoPets extends StatelessWidget {
  const _NoPets({required this.household, required this.uid});

  final Household household;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: household.adminIds.contains(uid)
            ? FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add your first pet'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => PetFormScreen(householdId: household.id),
                  ),
                ),
              )
            : Text(
                'No pets yet. Ask a household admin to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
      ),
    );
  }
}

/// Two columns of pet cards.
class _PetGrid extends StatelessWidget {
  const _PetGrid({required this.household, required this.uid, required this.pets});

  final Household household;
  final String uid;
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget card(int index) {
      final pet = pets[index];
      return Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openPetLogs(context, household: household, uid: uid, pet: pet),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                PetAvatar(pet: pet, index: index, size: 36, fontSize: 15),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        describePet(pet),
                        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          for (var row = 0; row < pets.length; row += 2)
            Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : 10),
              child: Row(
                children: [
                  Expanded(child: card(row)),
                  const SizedBox(width: 10),
                  Expanded(child: row + 1 < pets.length ? card(row + 1) : const SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A row of pet avatars that scrolls sideways.
class _PetRow extends StatelessWidget {
  const _PetRow({required this.household, required this.uid, required this.pets});

  final Household household;
  final String uid;
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, pet) in pets.indexed)
            Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => openPetLogs(context, household: household, uid: uid, pet: pet),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      PetAvatar(pet: pet, index: index, size: 56, fontSize: 20),
                      const SizedBox(height: 6),
                      Text(
                        pet.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The household's latest logs across every pet.
class _Recent extends ConsumerWidget {
  const _Recent({
    required this.household,
    required this.uid,
    required this.pets,
    required this.showAllPets,
  });

  final Household household;
  final String uid;
  final List<Pet> pets;

  /// Whether the header links to every pet, for when they don't all fit.
  final bool showAllPets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final key = (householdId: household.id, limit: _recentCount);
    final logsState = ref.watch(recentLogsProvider(key));
    final catalog = ref.watch(symptomCatalogProvider).value;
    final mute = TextStyle(fontSize: 13, color: colors.onSurfaceVariant);

    final Widget body = logsState.when(
      data: (logs) => logs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('Nothing logged yet', style: mute),
            )
          : Column(
              children: [
                for (final (index, (:pet, :log)) in logs.indexed)
                  _RecentRow(
                    pet: pet,
                    petIndex: pets.indexWhere((each) => each.id == pet.id),
                    log: log,
                    title: log.title ?? catalog?.symptom(log.symptom)?.label ?? log.symptom,
                    answers: switch (catalog?.symptom(log.symptom)) {
                      final symptom? => summarizeAnswers(symptom, log.answers),
                      null => '',
                    },
                    divider: index < logs.length - 1,
                  ),
              ],
            ),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text('$error', style: mute),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'RECENT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 12 * .06,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (showAllPets)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onPrimaryContainer,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => AllPetsScreen(household: household, uid: uid),
                    ),
                  ),
                  child: const Text('All pets'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          body,
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.pet,
    required this.petIndex,
    required this.log,
    required this.title,
    required this.answers,
    required this.divider,
  });

  final Pet pet;

  /// The pet's place in the household's list, which picks its colours.
  final int petIndex;
  final SymptomLog log;

  /// The `other` title, or the catalog label.
  final String title;

  /// The catalog answers summarised, or empty.
  final String answers;

  /// Whether a line separates this row from the next.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            )
          : null,
      child: Row(
        children: [
          PetAvatar(pet: pet, index: petIndex, size: 28, fontSize: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  answers.isEmpty ? pet.name : '${pet.name} · $answers',
                  style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatRecentTime(context, log.occurredAt),
            style: TextStyle(
              fontFamily: monoFontFamily,
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
