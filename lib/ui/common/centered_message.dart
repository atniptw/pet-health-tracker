import 'package:flutter/widgets.dart';

/// [text] centered on the screen, with room around it.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
