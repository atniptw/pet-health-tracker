import 'package:flutter/widgets.dart';

import '../data/repositories.dart';

/// Gives the widgets below it the app's repositories.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.pets,
    required this.eventTypes,
    required this.events,
    required super.child,
  });

  final PetRepository pets;
  final EventTypeRepository eventTypes;
  final EventRepository events;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      pets != oldWidget.pets || eventTypes != oldWidget.eventTypes || events != oldWidget.events;

  /// The nearest [AppScope] above [context].
  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope.of found no AppScope above the context.');
    return scope!;
  }
}
