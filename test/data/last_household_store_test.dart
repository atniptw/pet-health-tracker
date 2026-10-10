import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/data/last_household_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferencesAsync extends Mock implements SharedPreferencesAsync {}

void main() {
  late MockSharedPreferencesAsync prefs;
  late LastHouseholdStore store;

  setUp(() {
    prefs = MockSharedPreferencesAsync();
    store = LastHouseholdStore(prefs);
  });

  test("reads the user's last household", () async {
    when(() => prefs.getString('lastHouseholdId.u1')).thenAnswer((_) async => 'h2');

    expect(await store.read('u1'), 'h2');
  });

  test("writes the user's last household under their own key", () async {
    when(() => prefs.setString(any(), any())).thenAnswer((_) async {});

    await store.write('u1', 'h2');

    verify(() => prefs.setString('lastHouseholdId.u1', 'h2')).called(1);
  });
}
