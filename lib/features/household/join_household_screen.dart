import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import 'household_providers.dart';

/// Joins a household with an invite code from one of its admins.
class JoinHouseholdScreen extends ConsumerStatefulWidget {
  const JoinHouseholdScreen({required this.user, super.key});

  final User user;

  @override
  ConsumerState<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends ConsumerState<JoinHouseholdScreen> {
  final _codeController = TextEditingController();
  late final TextEditingController _nameController;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_joining) return;
    // The code is matched exactly, so only trailing spaces are dropped (by
    // the repository); the name is trimmed like everywhere else.
    final code = _codeController.text;
    final name = _nameController.text.trim();
    if (code.trim().isEmpty || name.isEmpty) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final householdId = await ref
          .read(householdRepositoryProvider)
          .joinHousehold(code: code, uid: widget.user.uid, name: name);
      await ref.read(lastHouseholdProvider(widget.user.uid).notifier).select(householdId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a household')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Enter the invite code an admin of the household shared with you.'),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Invite code',
              helperText: 'Type it exactly as shared, capitals and all',
            ),
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
          if (_joining)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(onPressed: _join, child: const Text('Join')),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
