import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/household.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/household/create_household_screen.dart';
import '../features/household/home_screen.dart';
import '../features/household/household_providers.dart';
import '../features/household/member_name_screen.dart';
import 'firebase_providers.dart';
import 'theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Health Tracker',
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) => user == null ? const SignInScreen() : HouseholdGate(user: user),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(authStateChangesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HouseholdGate extends ConsumerWidget {
  const HouseholdGate({required this.user, super.key});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdsState = ref.watch(myHouseholdsProvider(user.uid));

    return householdsState.when(
      data: (households) => households.isEmpty
          ? CreateHouseholdScreen(user: user)
          : _OpenHousehold(households: households, user: user),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(myHouseholdsProvider(user.uid)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The household the user last opened on this device, or their first one if
/// that isn't known or they're no longer in it.
class _OpenHousehold extends ConsumerWidget {
  const _OpenHousehold({required this.households, required this.user});

  final List<Household> households;
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastHouseholdProvider(user.uid));
    if (last.isLoading && !last.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final household = households.firstWhere(
      (each) => each.id == last.value,
      orElse: () => households.first,
    );
    return _NamedHome(key: ValueKey(household.id), household: household, user: user);
  }
}

/// The home screen, or a one-time prompt for the user's name if they have none
/// in this household. Shows home while that isn't known yet, so logging never
/// waits on it.
class _NamedHome extends ConsumerWidget {
  const _NamedHome({required this.household, required this.user, super.key});

  final Household household;
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameMissing = ref.watch(nameMissingProvider((householdId: household.id, uid: user.uid)));
    return nameMissing.value ?? false
        ? MemberNameScreen(household: household, user: user)
        : HomeScreen(household: household, uid: user.uid);
  }
}
