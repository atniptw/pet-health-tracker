import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/sign_in_screen.dart';
import '../features/household/create_household_screen.dart';
import '../features/household/home_screen.dart';
import '../features/household/household_providers.dart';
import 'firebase_providers.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Health Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
      ),
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
    final householdState = ref.watch(myHouseholdProvider(user.uid));

    return householdState.when(
      data: (household) => household == null
          ? CreateHouseholdScreen(user: user)
          : HomeScreen(household: household, uid: user.uid),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(myHouseholdProvider(user.uid)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
