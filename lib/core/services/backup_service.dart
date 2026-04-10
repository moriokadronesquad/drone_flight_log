import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// バックアップ・リストアサービス
/// 全データをJSON形式でエクスポート/インポートする
class BackupService {
  /// SharedPreferencesのキー一覧（アプリで使用しているもの）
  static const _dataKeys = [
    'drone_app_pilots',
    'drone_app_aircrafts',
    'drone_app_flights',
    'drone_app_inspections',
    'drone_app_maintenances',
    'drone_app_schedules',
    'drone_app_next_pilot_id',
    'drone_app_next_aircraft_id',
    'drone_app_next_flight_id',
    'drone_app_next_inspection_id',
    'drone_app_next_maintenance_id',
    'drone_app_next_schedule_id',
  ];

  /// 全データをJSON文字列としてエクスポート
  static Future<String> exportAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final backup = <String, dynamic>{
      'appName': 'ドローン飛行日誌',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
    };

    for (final key in _dataKeys) {
      final value = prefs.getString(key);
      if (value != null) {
        // JSONリストはデコードして保存（可読性のため）
        try {
          backup[key] = jsonDecode(value);
        } catch (_) {
          backup[key] = value;
        }
      }
    }

    // IDカウンターはintとして保存されている場合もある
    for (final key in _dataKeys) {
      if (key.contains('next_') && !backup.containsKey(key)) {
        final intVal = prefs.getInt(key);
        if (intVal != null) {
          backup[key] = intVal;
        }
      }
    }

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// JSON文字列からデータをリストア
  /// 既存データは上書きされる
  static Future<BackupRestoreResult> importAllData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // バリデーション: appNameが正しいか
      if (data['appName'] != 'ドローン飛行日誌') {
        return BackupRestoreResult(
          success: false,
          message: 'このファイルはドローン飛行日誌のバックアップではありません',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      var restoredCount = 0;

      for (final key in _dataKeys) {
        if (data.containsKey(key)) {
          final value = data[key];
          if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else {
            // List/Mapの場合はJSONエンコードして保存
            await prefs.setString(key, jsonEncode(value));
          }
          restoredCount++;
        }
      }

      return BackupRestoreResult(
        success: true,
        message: '$restoredCount件のデータを復元しました',
        restoredKeys: restoredCount,
      );
    } catch (e) {
      return BackupRestoreResult(
        success: false,
        message: 'バックアップデータの読み込みに失敗しました: $e',
      );
    }
  }

  /// 全データを削除する
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _dataKeys) {
      await prefs.remove(key);
    }
  }

  /// データ件数サマリーを取得
  static Future<Map<String, int>> getDataSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final summary = <String, int>{};

    int countJsonList(String key) {
      final raw = prefs.getString(key);
      if (raw == null) return 0;
      try {
        final list = jsonDecode(raw) as List;
        return list.length;
      } catch (_) {
        return 0;
      }
    }

    summary['操縦者'] = countJsonList('drone_app_pilots');
    summary['機体'] = countJsonList('drone_app_aircrafts');
    summary['飛行記録'] = countJsonList('drone_app_flights');
    summary['日常点検'] = countJsonList('drone_app_inspections');
    summary['整備記録'] = countJsonList('drone_app_maintenances');
    summary['スケジュール'] = countJsonList('drone_app_schedules');

    return summary;
  }
}

/// リストア結果を格納するクラス
class BackupRestoreResult {
  final bool success;
  final String message;
  final int restoredKeys;

  BackupRestoreResult({
    required this.success,
    required this.message,
    this.restoredKeys = 0,
  });
}
