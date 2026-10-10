import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/household.dart';
import '../../data/invite_code.dart';
import 'invite_providers.dart';

/// Lets an admin make the household's invite code and share it. The code is
/// shown only on the phone that made it.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({required this.household, required this.uid, super.key});

  final Household household;

  /// The signed-in admin.
  final String uid;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _codeController = TextEditingController();

  /// Whether the admin chose to replace the active code.
  bool _replacing = false;
  bool _creating = false;
  String? _error;

  ({String householdId, String uid}) get _key =>
      (householdId: widget.household.id, uid: widget.uid);

  @override
  void initState() {
    super.initState();
    // Ready in the form if there's no code yet.
    unawaited(_suggest());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    final words = await ref.read(inviteWordsProvider.future);
    if (!mounted) return;
    setState(() {
      _codeController.text = words.suggest();
      _error = null;
    });
  }

  Future<void> _startReplacing() async {
    setState(() => _replacing = true);
    await _suggest();
  }

  Future<void> _create() async {
    if (_creating) return;
    final code = normalizeInviteCode(_codeController.text);
    if (!isLongEnoughInviteCode(code)) {
      setState(() => _error = 'Use at least $minInviteCodeLength characters.');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await ref
          .read(inviteRepositoryProvider)
          .createInvite(householdId: widget.household.id, createdBy: widget.uid, code: code);
      // Saved once the invite exists, so clean-up never mistakes it for stale.
      await ref
          .read(inviteCodeStoreProvider)
          .write(uid: widget.uid, householdId: widget.household.id, code: code);
      ref.invalidate(inviteStateProvider(_key));
      if (mounted) setState(() => _replacing = false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _share(BuildContext buttonContext, String code) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    return ref.read(shareTextProvider)(
      'Join "${widget.household.name}" in Pet Health Tracker with this invite code: $code',
      origin,
    );
  }

  String _expiry(DateTime expiresAt) {
    final localizations = MaterialLocalizations.of(context);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(expiresAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '${localizations.formatMediumDate(expiresAt)} at $time';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inviteStateProvider(_key));
    return Scaffold(
      appBar: AppBar(title: const Text('Invite someone')),
      body: state.when(
        data: (state) => ListView(
          padding: const EdgeInsets.all(16),
          children: state.invite == null || _replacing
              ? _form(replacing: state.invite != null)
              : _active(state.code, state.invite!.expiresAt),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(inviteStateProvider(_key)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _active(String? code, DateTime expiresAt) {
    final textTheme = Theme.of(context).textTheme;
    final expiry = _expiry(expiresAt);
    return [
      if (code == null)
        Text(
          'A code is active until $expiry. It was made on another phone, so it '
          "can't be shown here. Make a new code to share one.",
        )
      else ...[
        Text('Anyone with this code can join as a member until $expiry.'),
        const SizedBox(height: 24),
        SelectableText(code, textAlign: TextAlign.center, style: textTheme.headlineSmall),
        const SizedBox(height: 24),
        Builder(
          builder: (buttonContext) => FilledButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            onPressed: () => _share(buttonContext, code),
          ),
        ),
      ],
      const SizedBox(height: 8),
      TextButton(onPressed: _startReplacing, child: const Text('Make a new code')),
    ];
  }

  List<Widget> _form({required bool replacing}) {
    return [
      const Text('Make a code to share. Anyone with it can join as a member for 7 days.'),
      if (replacing) ...[
        const SizedBox(height: 8),
        Text(
          'Your current code will stop working.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: _codeController,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: 'Invite code',
          helperText: 'At least $minInviteCodeLength characters. Type your own or use ours.',
          errorText: _error,
          suffixIcon: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Suggest another',
            onPressed: _suggest,
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (_creating)
        const Center(child: CircularProgressIndicator())
      else ...[
        FilledButton(onPressed: _create, child: const Text('Create code')),
        if (replacing)
          TextButton(
            onPressed: () => setState(() {
              _replacing = false;
              _error = null;
            }),
            child: const Text('Cancel'),
          ),
      ],
    ];
  }
}
