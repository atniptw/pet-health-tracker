import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import 'household_providers.dart';
import 'join_household_screen.dart';

class CreateHouseholdScreen extends ConsumerStatefulWidget {
  const CreateHouseholdScreen({required this.user, super.key});

  final User user;

  @override
  ConsumerState<CreateHouseholdScreen> createState() => _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends ConsumerState<CreateHouseholdScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _ownerNameController;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final displayName = widget.user.displayName;
    _nameController = TextEditingController(
      text: displayName == null || displayName.isEmpty
          ? 'My Household'
          : "$displayName's Household",
    );
    _ownerNameController = TextEditingController(text: displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating) return;
    final name = _nameController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    if (name.isEmpty || ownerName.isEmpty) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final householdId = await ref
          .read(householdRepositoryProvider)
          .createHousehold(name: name, ownerUid: widget.user.uid, ownerName: ownerName);
      await ref.read(lastHouseholdProvider(widget.user.uid).notifier).select(householdId);
      // Opened from the switcher: close, showing the new household.
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your household')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Household name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ownerNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name',
                helperText: 'Shown to the household on the symptoms you log',
              ),
            ),
            const SizedBox(height: 16),
            if (_creating)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(onPressed: _create, child: const Text('Create')),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => JoinHouseholdScreen(user: widget.user),
                ),
              ),
              child: const Text('Have an invite code? Join a household'),
            ),
          ],
        ),
      ),
    );
  }
}
