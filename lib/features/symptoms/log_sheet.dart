import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../../data/pet.dart';
import '../pets/pet_avatar.dart';
import 'symptom_providers.dart';

/// Up to this many pets are picked from a grid of pills; more from a row of
/// avatars.
const _gridMaxPets = 4;

/// How many "Logged before" titles the sheet offers.
const _loggedBeforeCount = 6;

/// Opens the sheet that logs a symptom for one of [pets], which mustn't be
/// empty.
Future<void> showLogSheet(
  BuildContext context, {
  required Household household,
  required String uid,
  required List<Pet> pets,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    barrierColor: const Color(0x6114100C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => LogSheet(household: household, uid: uid, pets: pets),
  );
}

/// Picks a pet and what happened, and saves the log straight away, timed now.
class LogSheet extends ConsumerStatefulWidget {
  const LogSheet({required this.household, required this.uid, required this.pets, super.key});

  final Household household;

  /// The signed-in user, recorded as the log's author.
  final String uid;

  /// The household's pets, in the list's order.
  final List<Pet> pets;

  @override
  ConsumerState<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends ConsumerState<LogSheet> {
  /// The pet the user picked. Until they pick one, the pet they last logged
  /// for, or the first pet.
  String? _pickedPetId;

  /// Whether the title field for "Something else…" shows.
  bool _typing = false;
  final _title = TextEditingController();
  bool _showMissing = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// The pet the user last logged for, if any.
  String? _lastLoggedPetId({required bool watch}) {
    final provider = lastLoggedPetIdProvider((householdId: widget.household.id, uid: widget.uid));
    return (watch ? ref.watch(provider) : ref.read(provider)).value;
  }

  Pet _selected(String? lastLoggedPetId) {
    final id = _pickedPetId ?? lastLoggedPetId;
    return widget.pets.firstWhere((pet) => pet.id == id, orElse: () => widget.pets.first);
  }

  /// Saves an `other` log for the selected pet, closes the sheet, and offers
  /// to undo it.
  void _logOther(String title) {
    final pet = _selected(_lastLoggedPetId(watch: false));
    final householdId = widget.household.id;
    final repository = ref.read(symptomLogRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    // Replaces the "logged" message, which a failed save makes untrue.
    void failed(Object e) => messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text("Couldn't save the log: $e")));

    final logId = repository.newLogId(householdId: householdId, petId: pet.id);
    // Not awaited, so logging works without signal. The local cache has the
    // log straight away.
    unawaited(
      repository
          .addOtherLog(
            householdId: householdId,
            petId: pet.id,
            logId: logId,
            createdBy: widget.uid,
            title: title,
            occurredAt: DateTime.now(),
          )
          .catchError(failed),
    );
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$title logged for ${pet.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(
            repository
                .deleteLog(householdId: householdId, petId: pet.id, logId: logId)
                .catchError(failed),
          ),
        ),
      ),
    );
  }

  void _saveTitle() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _showMissing = true);
      return;
    }
    _logOther(title);
  }

  @override
  Widget build(BuildContext context) {
    final lastLoggedPetId = _lastLoggedPetId(watch: true);
    final pet = _selected(lastLoggedPetId);
    final pets = widget.pets;
    final lastLogged = pets.where((each) => each.id == lastLoggedPetId).firstOrNull;

    final Widget who;
    if (pets.length <= _gridMaxPets) {
      who = _Section(
        label: 'Who',
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _PetPills(pets: pets, selected: pet, onPicked: _pick),
      );
    } else {
      who = _Section(
        label: lastLogged == null ? 'Who' : 'Who · last logged for ${lastLogged.name}',
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: _PetAvatars(
          // The pet last logged for comes first.
          pets: [?lastLogged, ...pets.where((each) => each != lastLogged)],
          indexOf: pets.indexOf,
          selected: pet,
          onPicked: _pick,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pets.length > 1) ...[who, const SizedBox(height: 14)],
            if (_typing)
              _TitleField(
                controller: _title,
                showMissing: _showMissing,
                onChanged: () => setState(() {}),
                onBack: () => setState(() {
                  _typing = false;
                  _showMissing = false;
                }),
                onSave: _saveTitle,
              )
            else ...[
              _Section(
                label: 'What happened',
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SomethingElseRow(onTap: () => setState(() => _typing = true)),
              ),
              _LoggedBefore(householdId: widget.household.id, pet: pet, onPicked: _logOther),
            ],
          ],
        ),
      ),
    );
  }

  void _pick(Pet pet) => setState(() => _pickedPetId = pet.id);
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.padding,
    required this.child,
    this.labelPadding = EdgeInsets.zero,
  });

  final String label;

  /// Around the label and the child.
  final EdgeInsets padding;

  /// Around the label only, for children that run to the sheet's edges.
  final EdgeInsets labelPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: labelPadding,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Two columns of pet pills. The selected one is ticked.
class _PetPills extends StatelessWidget {
  const _PetPills({required this.pets, required this.selected, required this.onPicked});

  final List<Pet> pets;
  final Pet selected;
  final ValueChanged<Pet> onPicked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget pill(int index) {
      final pet = pets[index];
      final isSelected = pet.id == selected.id;
      return Material(
        color: isSelected ? colors.primaryContainer : Colors.transparent,
        shape: StadiumBorder(
          side: isSelected
              ? BorderSide(color: colors.primary, width: 2)
              : BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onPicked(pet),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.only(left: 6, right: 12),
              child: Row(
                children: [
                  if (isSelected)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                      child: Icon(Icons.check, size: 20, color: colors.onPrimary),
                    )
                  else
                    PetAvatar(pet: pet, index: index, size: 34, fontSize: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pet.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? colors.onPrimaryContainer : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var row = 0; row < pets.length; row += 2)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 8),
            child: Row(
              children: [
                Expanded(child: pill(row)),
                const SizedBox(width: 8),
                Expanded(child: row + 1 < pets.length ? pill(row + 1) : const SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

/// A row of pet avatars that scrolls sideways. The selected one is filled and
/// ringed.
class _PetAvatars extends StatelessWidget {
  const _PetAvatars({
    required this.pets,
    required this.indexOf,
    required this.selected,
    required this.onPicked,
  });

  /// In the order shown.
  final List<Pet> pets;

  /// A pet's place in the household's list, which picks its colours.
  final int Function(Pet pet) indexOf;
  final Pet selected;
  final ValueChanged<Pet> onPicked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, pet) in pets.indexed)
            Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 12),
              child: _avatar(context, colors, pet, isSelected: pet.id == selected.id),
            ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, ColorScheme colors, Pet pet, {required bool isSelected}) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onPicked(pet),
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              if (isSelected)
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: colors.primary, spreadRadius: 5),
                      BoxShadow(color: colors.surfaceContainerLow, spreadRadius: 3),
                    ],
                  ),
                  child: Text(
                    pet.name.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimary,
                    ),
                  ),
                )
              else
                PetAvatar(pet: pet, index: indexOf(pet), size: 56, fontSize: 20),
              const SizedBox(height: 6),
              Text(
                pet.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? colors.onPrimaryContainer : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SomethingElseRow extends StatelessWidget {
  const _SomethingElseRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mute = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 18, color: mute),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Something else…',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The title of an `other` log, typed in place of the symptom list.
class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.showMissing,
    required this.onChanged,
    required this.onBack,
    required this.onSave,
  });

  final TextEditingController controller;

  /// Whether Save was tapped with no title.
  final bool showMissing;
  final VoidCallback onChanged;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'What happened',
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Something else…',
              errorText: showMissing && controller.text.trim().isEmpty ? 'Enter a title' : null,
            ),
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSave(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(onPressed: onBack, child: const Text('Back')),
              const Spacer(),
              FilledButton(onPressed: onSave, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chips for the pet's recent `other` titles. Tapping one logs it again.
class _LoggedBefore extends ConsumerWidget {
  const _LoggedBefore({required this.householdId, required this.pet, required this.onPicked});

  final String householdId;
  final Pet pet;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles =
        ref
            .watch(
              recentOtherTitlesProvider((
                householdId: householdId,
                petId: pet.id,
                limit: _loggedBeforeCount,
              )),
            )
            .value ??
        const <String>[];
    if (titles.isEmpty) return const SizedBox();

    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _Section(
        label: 'Logged before for ${pet.name}',
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final title in titles)
              ActionChip(
                label: Text(title),
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
                onPressed: () => onPicked(title),
              ),
          ],
        ),
      ),
    );
  }
}
