import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';

/// Asks a member with no name in [household] for one. Shown once: saving
/// creates their member doc, and the gate then shows the home screen.
class MemberNameScreen extends ConsumerStatefulWidget {
  const MemberNameScreen({required this.household, required this.user, super.key});

  final Household household;
  final User user;

  @override
  ConsumerState<MemberNameScreen> createState() => _MemberNameScreenState();
}

class _MemberNameScreenState extends ConsumerState<MemberNameScreen> {
  late final TextEditingController _nameController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(householdRepositoryProvider)
          .addMemberName(householdId: widget.household.id, uid: widget.user.uid, name: name);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.household.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What should your household call you?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name',
                helperText: 'Shown to the household on the symptoms you log',
              ),
            ),
            const SizedBox(height: 16),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(onPressed: _save, child: const Text('Save')),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
