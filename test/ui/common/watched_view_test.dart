import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/ui/common/watched_view.dart';

const loadFailed = "The names couldn't be loaded.";

Widget viewOf(Stream<String?> stream, {Key? key, String? failed = loadFailed}) => MaterialApp(
  home: Scaffold(
    body: WatchedView<String?>(
      key: key,
      stream: stream,
      what: 'Reading the names',
      loadFailed: failed,
      builder: (context, name) => Text('Name: $name'),
    ),
  ),
);

void main() {
  testWidgets('shows nothing before the first value, then the latest value', (tester) async {
    final names = StreamController<String?>();
    addTearDown(names.close);
    await tester.pumpWidget(viewOf(names.stream));

    expect(find.byType(Text), findsNothing);
    names.add('Rex');
    await tester.pumpAndSettle();
    expect(find.text('Name: Rex'), findsOneWidget);
    names.add('Mia');
    await tester.pumpAndSettle();
    expect(find.text('Name: Mia'), findsOneWidget);
  });

  testWidgets('a null value counts as read', (tester) async {
    final names = StreamController<String?>();
    addTearDown(names.close);
    await tester.pumpWidget(viewOf(names.stream));

    names.add(null);
    await tester.pumpAndSettle();

    expect(find.text('Name: null'), findsOneWidget);
  });

  testWidgets('a failed read before any value is reported without its message and shows the '
      'load failed message, until a value is read', (tester) async {
    final names = StreamController<String?>();
    addTearDown(names.close);
    await tester.pumpWidget(viewOf(names.stream));

    names.addError(Exception('SELECT failed for Rex'));
    await tester.pumpAndSettle();

    final error = tester.takeException();
    expect(error, isA<StateError>());
    expect(error.toString(), contains('Reading the names failed'));
    expect(error.toString(), isNot(contains('Rex')));
    expect(find.text(loadFailed), findsOneWidget);
    names.add('Rex');
    await tester.pumpAndSettle();
    expect(find.text(loadFailed), findsNothing);
    expect(find.text('Name: Rex'), findsOneWidget);
  });

  testWidgets('a failed read before any value, with no load failed message, is reported and '
      'shows nothing', (tester) async {
    final names = StreamController<String?>();
    addTearDown(names.close);
    await tester.pumpWidget(viewOf(names.stream, failed: null));

    names.addError(Exception('SELECT failed for Rex'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StateError>());
    expect(find.byType(Text), findsNothing);
    names.add('Rex');
    await tester.pumpAndSettle();
    expect(find.text('Name: Rex'), findsOneWidget);
  });

  testWidgets('a failed read after a value keeps the value shown', (tester) async {
    final names = StreamController<String?>();
    addTearDown(names.close);
    await tester.pumpWidget(viewOf(names.stream));
    names.add('Rex');
    await tester.pumpAndSettle();

    names.addError(Exception('SELECT failed'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNotNull);
    expect(find.text(loadFailed), findsNothing);
    expect(find.text('Name: Rex'), findsOneWidget);
  });

  testWidgets('a rebuild with the same stream keeps listening to it once', (tester) async {
    final names = StreamController<String?>();
    addTearDown(names.close);
    final key = GlobalKey();
    await tester.pumpWidget(viewOf(names.stream, key: key));
    names.add('Rex');
    await tester.pumpAndSettle();

    await tester.pumpWidget(viewOf(names.stream, key: key));

    expect(tester.takeException(), isNull);
    expect(find.text('Name: Rex'), findsOneWidget);
  });

  testWidgets('another stream starts over from it, and the first is no longer followed', (
    tester,
  ) async {
    final first = StreamController<String?>();
    final second = StreamController<String?>();
    addTearDown(first.close);
    addTearDown(second.close);
    final key = GlobalKey();
    await tester.pumpWidget(viewOf(first.stream, key: key));
    first.addError(Exception('SELECT failed'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNotNull);

    await tester.pumpWidget(viewOf(second.stream, key: key));

    expect(first.hasListener, isFalse);
    expect(find.byType(Text), findsNothing);
    second.add('Mia');
    await tester.pumpAndSettle();
    expect(find.text('Name: Mia'), findsOneWidget);
  });

  testWidgets('stops listening when removed', (tester) async {
    final names = StreamController<String?>();
    addTearDown(names.close);
    await tester.pumpWidget(viewOf(names.stream));

    await tester.pumpWidget(const SizedBox());

    expect(names.hasListener, isFalse);
  });
}
