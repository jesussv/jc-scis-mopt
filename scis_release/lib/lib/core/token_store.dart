import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _kToken = 'access_token';
  static const _kExp = 'expires_at_utc';

  Future<void> save(String token, String expiresAtUtc) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, token);
    await sp.setString(_kExp, expiresAtUtc);
  }

  Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kExp);
  }
}
