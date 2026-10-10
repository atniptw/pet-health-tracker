import 'package:shared_preferences/shared_preferences.dart';

/// Remembers on this device which household each user last opened.
class LastHouseholdStore {
  LastHouseholdStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  String _key(String uid) => 'lastHouseholdId.$uid';

  Future<String?> read(String uid) => _prefs.getString(_key(uid));

  Future<void> write(String uid, String householdId) => _prefs.setString(_key(uid), householdId);
}
