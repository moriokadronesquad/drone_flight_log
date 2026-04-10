import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// フォーム下書き自動保存サービス
///
/// フォーム入力中のデータを定期的にSharedPreferencesに保存し、
/// 意図しない画面離脱時にデータを復元できるようにする。
/// フォームの種類ごとにキーを分けて管理する。
class DraftService {
  static const _prefix = 'drone_draft_';

  /// ドラフトのキー一覧
  static const keyFlightForm = '${_prefix}flight';
  static const keyInspectionForm = '${_prefix}inspection';
  static const keyMaintenanceForm = '${_prefix}maintenance';

  /// ドラフトを保存する
  static Future<void> saveDraft(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  /// ドラフトを読み込む（存在しなければnull）
  static Future<Map<String, dynamic>?> loadDraft(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// ドラフトを削除する（保存完了時やフォームリセット時に呼ぶ）
  static Future<void> clearDraft(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// ドラフトが存在するか確認
  static Future<bool> hasDraft(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }
}
