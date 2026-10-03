import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/features/household/home_screen.dart';

import '../helpers.dart';

void main() {
  const household = Household(id: 'h1', name: 'The Den', memberIds: ['u1'], adminIds: ['u1']);

  testWidgets('shows the household name', (tester) async {
    await tester.pumpScoped(const HomeScreen(household: household));

    expect(find.text('The Den'), findsWidgets);
  });

  testWidgets('signs out from the app bar', (tester) async {
    final auth = MockAuthRepository();
    when(auth.signOut).thenAnswer((_) async {});

    await tester.pumpScoped(
      const HomeScreen(household: household),
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();

    verify(auth.signOut).called(1);
  });
}
