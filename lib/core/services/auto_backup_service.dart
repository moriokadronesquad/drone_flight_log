import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';

/// 自動バックアップサービス
/// アプリ起動時に最終バックアップ日をチェックし、
/// 一定期間経過していたら自動でバックアップを実行する
class AutoBackupService {
  static const _enabledKey = 'drone_app_auto_backup_enabled';
  static const _intervalKey = 'drone_app_auto_backup_interval'; // 日数
  static const _lastBackupKey = 'drone_app_last_auto_backup';
  static const _lastBackupDataKey = 'drone_app_last_backup_data';

  /// 自動バックアップが有効か
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// 自動バックアップを有効/無効に設定
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// バックアップ間隔（日数）を取得
  static Future<int> getInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_intervalKey) ?? 7; // デフォルト7日
  }

  /// バックアップ間隔を設定
  static Future<void> setInterval(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_intervalKey, days);
  }

  /// 最終バックアップ日時を取得
  static Future<String?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastBackupKey);
  }

  /// 最終バックアップデータを取得（SharedPreferencesに保存済み）
  static Future<String?> getLastBackupData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastBackupDataKey);
  }

  /// 起動時チェック：バックアップが必要か判定して実行
  /// 返値: バックアップ実行された場合true
  static Future<bool> checkAndBackup() async {
    final enabled = await isEnabled();
    if (!enabled) return false;

    final interval = await getInterval();
    final lastDateStr = await getLastBackupDate();

    var needsBackup = false;

    if (lastDateStr == null) {
      // 一度もバックアップしていない
      needsBackup = true;
    } else {
      try {
        final lastDate = DateTime.parse(lastDateStr);
        final daysSince = DateTime.now().difference(lastDate).inDays;
        needsBackup = daysSince >= interval;
      } catch (_) {
        needsBackup = true;
      }
    }

    if (!needsBackup) return false;

    try {
      final jsonString = await BackupService.exportAllData();

      // SharedPreferencesに保存（ローカルバックアップ）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupDataKey, jsonString);
      await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());

      debugPrint('AutoBackup: 自動バックアップ完了');
      return true;
    } catch (e) {
      debugPrint('AutoBackup: バックアップ失敗: $e');
      return false;
    }
  }

  /// 最終バックアップからの経過日数
  static Future<int?> daysSinceLastBackup() async {
    final lastDateStr = await getLastBackupDate();
    if (lastDateStr == null) return null;
    try {
      final lastDate = DateTime.parse(lastDateStr);
      return DateTime.now().difference(lastDate).inDays;
    } catch (_) {
      return null;
    }
  }

  /// 最終バックアップ日時のフォーマット文字列
  static Future<String> getLastBackupDateFormatted() async {
    final lastDateStr = await getLastBackupDate();
    if (lastDateStr == null) return '未実行';
    try {
      final lastDate = DateTime.parse(lastDateStr);
      return DateFormat('yyyy/MM/dd HH:mm').format(lastDate);
    } catch (_) {
      return '不明';
    }
  }
}
