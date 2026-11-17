import 'package:flutter/material.dart';

import '../../domain/durations.dart';
import '../../domain/frequency.dart';
import '../../domain/medical_event.dart';
import '../common/value_choices.dart';

/// The period choices, then a row per type with an event in the picked period
/// (FR-010): its name, "3 times", "about every 3.5 days" when it happened at
/// least twice, and "last 5 hours ago"; or "Nothing logged in this period".
class TypeSummaryList extends StatefulWidget {
  const TypeSummaryList({
    super.key,
    required this.events,
    required this.now,
    required this.typeName,
  });

  /// The pet's events.
  final List<MedicalEvent> events;

  /// The moment the periods end at.
  final DateTime now;

  /// The name of the type with the given id, removed or not.
  final String Function(String typeId) typeName;

  @override
  State<TypeSummaryList> createState() => _TypeSummaryListState();
}

class _TypeSummaryListState extends State<TypeSummaryList> {
  Period _period = Period.defaultPeriod;

  @override
  Widget build(BuildContext context) {
    final rows = summaries(widget.events, _period, widget.now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ValueChoices(
            values: Period.values,
            label: (period) => _periodLabels[period]!,
            picked: _period,
            onPicked: (period) => setState(() => _period = period),
          ),
        ),
        if (rows.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('Nothing logged in this period')),
        for (final row in rows) _SummaryRow(row, widget.typeName(row.typeId), widget.now),
      ],
    );
  }
}

const _periodLabels = {
  Period.last30Days: '30 days',
  Period.last90Days: '90 days',
  Period.last12Months: '12 months',
  Period.allTime: 'All time',
};

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.summary, this.name, this.now);

  final TypeSummary summary;
  final String name;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final averageGap = summary.averageGap;
    return ListTile(
      title: Text(name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(countText(summary.count, 'time')),
          if (averageGap != null) Text('about every ${averageText(averageGap)}'),
          Text('last ${gapText(now.difference(summary.lastAt))} ago'),
        ],
      ),
    );
  }
}
