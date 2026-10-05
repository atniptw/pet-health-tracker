import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/pet.dart';

/// Adds a pet, or edits [pet] when one is given.
class PetFormScreen extends ConsumerStatefulWidget {
  const PetFormScreen({required this.householdId, this.pet, super.key});

  final String householdId;
  final Pet? pet;

  @override
  ConsumerState<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends ConsumerState<PetFormScreen> {
  late final _nameController = TextEditingController(text: widget.pet?.name);
  late final _breedController = TextEditingController(text: widget.pet?.breed);
  late Species? _species = widget.pet?.species;
  late Sex? _sex = widget.pet?.sex;
  late DateTime? _birthDate = widget.pet?.birthDate;
  bool _saving = false;
  bool _showMissing = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now,
      firstDate: DateTime(now.year - 50),
      lastDate: now,
      helpText: 'Birth date',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final species = _species;
    if (name.isEmpty || species == null) {
      setState(() => _showMissing = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(petRepositoryProvider);
    final breed = _breedController.text.trim();
    final pet = widget.pet;
    try {
      if (pet == null) {
        await repository.addPet(
          householdId: widget.householdId,
          name: name,
          species: species,
          breed: breed,
          birthDate: _birthDate,
          sex: _sex,
        );
      } else {
        await repository.updatePet(
          householdId: widget.householdId,
          petId: pet.id,
          name: name,
          species: species,
          breed: breed,
          birthDate: _birthDate,
          sex: _sex,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final birthDate = _birthDate;
    final editing = widget.pet != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit ${widget.pet!.name}' : 'Add a pet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            autofocus: !editing,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: _showMissing && _nameController.text.trim().isEmpty
                  ? 'Enter a name'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text('Species', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<Species>(
            segments: [
              for (final species in Species.values)
                ButtonSegment(value: species, label: Text(species.label)),
            ],
            selected: {?_species},
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) =>
                setState(() => _species = selection.isEmpty ? null : selection.single),
          ),
          if (_showMissing && _species == null) ...[
            const SizedBox(height: 8),
            Text('Choose a species', style: TextStyle(color: errorColor)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _breedController,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Breed (optional)'),
          ),
          const SizedBox(height: 8),
          Text('Sex (optional)', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<Sex>(
            segments: [
              for (final sex in Sex.values) ButtonSegment(value: sex, label: Text(sex.label)),
            ],
            selected: {?_sex},
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) =>
                setState(() => _sex = selection.isEmpty ? null : selection.single),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Birth date (optional)'),
            subtitle: Text(
              birthDate == null
                  ? 'Not set'
                  : MaterialLocalizations.of(context).formatFullDate(birthDate),
            ),
            onTap: _pickBirthDate,
            trailing: birthDate == null
                ? const Icon(Icons.calendar_today)
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear birth date',
                    onPressed: () => setState(() => _birthDate = null),
                  ),
          ),
          const SizedBox(height: 16),
          if (_saving)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(onPressed: _save, child: Text(editing ? 'Save' : 'Add pet')),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: errorColor)),
          ],
        ],
      ),
    );
  }
}
