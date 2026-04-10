import 'package:shared_preferences/shared_preferences.dart';

/// アプリロックサービス
/// PINコードによるアプリ起動時の認証機能を提供
class AppLockService {
  static const _enabledKey = 'drone_app_lock_enabled';
  static const _pinKey = 'drone_app_lock_pin';

  /// アプリロックが有効かどうか
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// PINが設定されているか
  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_pinKey);
    return pin != null && pin.isNotEmpty;
  }

  /// PINを検証
  static Future<bool> verifyPin(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey);
    return stored == input;
  }

  /// PINを設定してロックを有効化
  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_enabledKey, true);
  }

  /// PINを変更
  static Future<bool> changePin(String oldPin, String newPin) async {
    final valid = await verifyPin(oldPin);
    if (!valid) return false;
    await setPin(newPin);
    return true;
  }

  /// ロックを無効化してPINを削除
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_pinKey);
  }
}
