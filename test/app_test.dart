import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app.dart';

void main() {
  testWidgets('says the app is being rebuilt', (tester) async {
    await tester.pumpWidget(const App());

    expect(find.text(App.message), findsOneWidget);
  });
}
