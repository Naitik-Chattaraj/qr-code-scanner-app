import 'package:shared_preferences/shared_preferences.dart';
import '../constants/config.dart';

class AuthService {
  static const String _authKey = 'is_authenticated';

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }

  Future<bool> login(String passcode) async {
    if (passcode == Config.teamPasscode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authKey, true);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
  }
}
