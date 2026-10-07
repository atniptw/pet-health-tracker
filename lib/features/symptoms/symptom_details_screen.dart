import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../../data/symptom_catalog.dart';
import '../../data/symptom_log.dart';
import '../../data/symptom_log_repository.dart';
import 'occurred_at.dart';
import 'symptom_providers.dart';

/// The catalog questions for a saved log, and its note. Every change is
/// written to the log as it's made; typed answers and the note are written
/// when the field is left or the screen closes.
class SymptomDetailsScreen extends ConsumerStatefulWidget {
  const SymptomDetailsScreen({
    required this.householdId,
    required this.petId,
    required this.petName,
    required this.log,
    super.key,
  });

  final String householdId;
  final String petId;
  final String petName;

  /// A catalog symptom log, as it was when the screen opened.
  final SymptomLog log;

  @override
  ConsumerState<SymptomDetailsScreen> createState() => _SymptomDetailsScreenState();
}

class _SymptomDetailsScreenState extends ConsumerState<SymptomDetailsScreen> {
  // Kept so the last typed changes can still be written in dispose.
  late final SymptomLogRepository _repository = ref.read(symptomLogRepositoryProvider);
  late ScaffoldMessengerState _messenger;

  /// The answers as last written. Yes/no answers are stored only when true,
  /// and removed answers are left out.
  late final Map<String, Object?> _answers = {...widget.log.answers};

  /// Number and text questions, keyed by question key.
  final _fields =
      <String, ({CatalogQuestion question, TextEditingController text, FocusNode focus})>{};

  /// When it happened, as last written.
  late DateTime _occurredAt = widget.log.occurredAt;

  late final _notes = TextEditingController(text: widget.log.notes);
  late final _notesFocus = FocusNode()..addListener(_onNotesFocusChanged);
  late String _savedNotes = widget.log.notes ?? '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      _saveField(field.question, field.text);
      field.text.dispose();
      field.focus.dispose();
    }
    _saveNotes();
    _notes.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  /// Not awaited, so changes save without signal. The local cache has them
  /// straight away.
  void _write(Future<void> write) {
    unawaited(
      write.catchError((Object e) {
        _messenger.showSnackBar(SnackBar(content: Text("Couldn't save the log: $e")));
      }),
    );
  }

  /// Writes one answer. Null removes it.
  void _saveAnswer(String key, Object? value) {
    if (value == null) {
      _answers.remove(key);
    } else {
      _answers[key] = value;
    }
    _write(
      _repository.updateAnswers(
        householdId: widget.householdId,
        petId: widget.petId,
        logId: widget.log.id,
        answers: {key: value},
      ),
    );
  }

  void _setAnswer(String key, Object? value) => setState(() => _saveAnswer(key, value));

  void _saveField(CatalogQuestion question, TextEditingController text) {
    final input = text.text.trim();
    final Object? value = input.isEmpty || question.type == QuestionType.text
        ? (input.isEmpty ? null : input)
        : int.tryParse(input);
    // A number stored as, say, 90.0 shows as typed and doesn't parse; it's
    // only rewritten once edited.
    if (value == null && input.isNotEmpty) return;
    if (value != _answers[question.key]) _saveAnswer(question.key, value);
  }

  Future<void> _pickOccurredAt() async {
    final occurredAt = await pickOccurredAt(context, _occurredAt);
    if (occurredAt == null || occurredAt == _occurredAt) return;
    setState(() => _occurredAt = occurredAt);
    _write(
      _repository.updateOccurredAt(
        householdId: widget.householdId,
        petId: widget.petId,
        logId: widget.log.id,
        occurredAt: occurredAt,
      ),
    );
  }

  void _onNotesFocusChanged() {
    if (!_notesFocus.hasFocus) _saveNotes();
  }

  void _saveNotes() {
    final notes = _notes.text.trim();
    if (notes == _savedNotes) return;
    _savedNotes = notes;
    _write(
      _repository.updateNotes(
        householdId: widget.householdId,
        petId: widget.petId,
        logId: widget.log.id,
        notes: notes,
      ),
    );
  }

  /// The text field state for a number or text question, made on first use.
  ({CatalogQuestion question, TextEditingController text, FocusNode focus}) _field(
    CatalogQuestion question,
  ) {
    return _fields.putIfAbsent(question.key, () {
      final text = TextEditingController(text: _answers[question.key]?.toString());
      final focus = FocusNode();
      focus.addListener(() {
        if (!focus.hasFocus) _saveField(question, text);
      });
      return (question: question, text: text, focus: focus);
    });
  }

  /// Retired questions only show when the log already answers them.
  bool _shows(CatalogQuestion question) => !question.retired || _answers.containsKey(question.key);

  @override
  Widget build(BuildContext context) {
    final symptom = ref.watch(symptomCatalogProvider).value?.symptom(widget.log.symptom);
    final questions = (symptom?.questions ?? const <CatalogQuestion>[]).where(_shows).toList();

    final children = <Widget>[];
    var i = 0;
    final occurred = _OccurredRow(occurredAt: _occurredAt, onTap: _pickOccurredAt);
    while (i < questions.length) {
      final question = questions[i];
      if (question.type == QuestionType.yesNo) {
        // Consecutive yes/no questions form one list of switches.
        final end = questions.indexWhere((next) => next.type != QuestionType.yesNo, i);
        final group = questions.sublist(i, end == -1 ? questions.length : end);
        i += group.length;
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 6 : 12),
            child: _YesNoGroup(
              questions: group,
              answers: _answers,
              onChanged: (key, value) => _setAnswer(key, value ? true : null),
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 6 : 18),
            child: _Section(label: question.label, child: _control(question)),
          ),
        );
        i++;
      }
    }
    children.add(
      Padding(
        padding: EdgeInsets.only(top: children.isEmpty ? 6 : 8),
        child: TextField(
          key: const ValueKey('notes'),
          controller: _notes,
          focusNode: _notesFocus,
          maxLength: 2000,
          minLines: 1,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 15),
          decoration: _fieldDecoration(context, hint: 'Add a note'),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: _Header(
          title: symptom?.label ?? widget.log.symptom,
          petName: widget.petName,
          occurredAt: _occurredAt,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                minimumSize: const Size(0, 40),
                // From the theme, so it keeps the app font.
                textStyle: Theme.of(context).textTheme.labelLarge!
                    .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [occurred, ...children],
      ),
    );
  }

  Widget _control(CatalogQuestion question) {
    switch (question.type) {
      case QuestionType.singleChoice:
        return _SingleChoice(
          question: question,
          selected: _answers[question.key] as String?,
          onChanged: (option) => _setAnswer(question.key, option),
        );
      case QuestionType.multipleChoice:
        final selected = [...((_answers[question.key] as List?) ?? const []).cast<String>()];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in question.options)
              if (!option.retired || selected.contains(option.key))
                FilterChip(
                  label: Text(option.label),
                  selected: selected.contains(option.key),
                  onSelected: (picked) {
                    final keys = picked
                        ? [...selected, option.key]
                        : [...selected.where((key) => key != option.key)];
                    _setAnswer(question.key, keys.isEmpty ? null : keys);
                  },
                ),
          ],
        );
      case QuestionType.number:
      case QuestionType.text:
        final field = _field(question);
        final number = question.type == QuestionType.number;
        return TextField(
          key: ValueKey(question.key),
          controller: field.text,
          focusNode: field.focus,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
          maxLength: number ? 9 : 2000,
          textCapitalization: number ? TextCapitalization.none : TextCapitalization.sentences,
          style: const TextStyle(fontSize: 15),
          decoration: _fieldDecoration(context, suffix: question.unit),
        );
      case QuestionType.yesNo:
        throw StateError('yes/no questions are shown as a group');
    }
  }
}

InputDecoration _fieldDecoration(BuildContext context, {String? hint, String? suffix}) {
  final colors = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.onSurfaceVariant),
    suffixText: suffix,
    suffixStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
    counterText: '',
    filled: true,
    fillColor: colors.surfaceContainerLow,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: border(colors.outlineVariant, 1),
    focusedBorder: border(colors.primary, 2),
  );
}

/// "Seizure", then "Boogie · 6:40 AM" with the time in the mono font. Logs
/// from another day show the full date.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.petName, required this.occurredAt});

  final String title;
  final String petName;
  final DateTime occurredAt;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today =
        occurredAt.year == now.year && occurredAt.month == now.month && occurredAt.day == now.day;
    final when = today
        ? MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt))
        : formatOccurredAt(context, occurredAt);
    final mute = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        Text.rich(
          TextSpan(
            text: '$petName · ',
            children: [
              TextSpan(
                text: when,
                style: const TextStyle(fontFamily: monoFontFamily),
              ),
            ],
          ),
          style: TextStyle(fontSize: 12, color: mute),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// "Occurred" and when, which opens the date and time pickers on tap.
class _OccurredRow extends StatelessWidget {
  const _OccurredRow({required this.occurredAt, required this.onTap});

  final DateTime occurredAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mute = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      key: const ValueKey('occurredAt'),
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Text('Occurred', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                formatOccurredAt(context, occurredAt),
                textAlign: TextAlign.end,
                style: TextStyle(fontFamily: monoFontFamily, fontSize: 13, color: mute),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.schedule, size: 20, color: mute),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// A segmented button when the options are few and short, as in the design;
/// chips otherwise, so long labels have room. Picking the selected option
/// again clears it.
class _SingleChoice extends StatelessWidget {
  const _SingleChoice({required this.question, required this.selected, required this.onChanged});

  final CatalogQuestion question;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final option in question.options)
        if (!option.retired || option.key == selected) option,
    ];
    final segmented = options.length <= 3 && options.every((option) => option.label.length <= 12);
    if (!segmented) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option.label),
              selected: option.key == selected,
              onSelected: (picked) => onChanged(picked ? option.key : null),
            ),
        ],
      );
    }

    final colors = Theme.of(context).colorScheme;
    return SegmentedButton<String>(
      key: ValueKey(question.key),
      segments: [
        for (final option in options)
          ButtonSegment(
            value: option.key,
            label: _SegmentLabel(label: option.label, selected: option.key == selected),
          ),
      ],
      selected: {?selected},
      emptySelectionAllowed: true,
      // The label draws its own check, closer to the text than the built-in one.
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: colors.primaryContainer,
        selectedForegroundColor: colors.onPrimaryContainer,
        side: BorderSide(color: colors.outlineVariant),
        textStyle: Theme.of(context).textTheme.labelLarge!
            .copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      onSelectionChanged: (keys) => onChanged(keys.isEmpty ? null : keys.single),
    );
  }
}

/// A check, when selected, then the label on one line, shrunk to fit if the
/// segment is narrow.
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[const Icon(Icons.check_rounded, size: 16), const SizedBox(width: 4)],
          Text(
            label,
            maxLines: 1,
            style: selected ? const TextStyle(fontWeight: FontWeight.w600) : null,
          ),
        ],
      ),
    );
  }
}

/// Switch rows, divided by lines. Tapping the label flips the switch too.
class _YesNoGroup extends StatelessWidget {
  const _YesNoGroup({required this.questions, required this.answers, required this.onChanged});

  final List<CatalogQuestion> questions;
  final Map<String, Object?> answers;
  final void Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (index, question) in questions.indexed) ...[
          if (index > 0) Divider(height: 1, thickness: 1, color: colors.outlineVariant),
          MergeSemantics(
            child: InkWell(
              onTap: () => onChanged(question.key, answers[question.key] != true),
              child: SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(child: Text(question.label, style: const TextStyle(fontSize: 15))),
                    Switch(
                      key: ValueKey(question.key),
                      value: answers[question.key] == true,
                      onChanged: (value) => onChanged(question.key, value),
                      activeTrackColor: colors.primary,
                      inactiveTrackColor: colors.outlineVariant,
                      thumbColor: const WidgetStatePropertyAll(Colors.white),
                      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
