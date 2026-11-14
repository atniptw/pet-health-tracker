import 'package:flutter/material.dart';

/// A single screen saying the app is being rebuilt from the specs in `specs/`.
class App extends StatelessWidget {
  const App({super.key});

  static const message = 'Pet Health Tracker is being rebuilt.';

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Pet Health Tracker',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
