import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 操作ログの種別
enum AuditAction {
  create('作成'),
  update('更新'),
  delete('削除'),
  export_('エクスポート'),
  import_('インポート'),
  backup('バックアップ'),
  restore('リストア'),
  login('ログイン'),
  setting('設定変更');

  final String label;
  const AuditAction(this.label);
}

/// 操作ログエントリ
class AuditLogEntry {
  final String timestamp;
  final String action;
  final String target;
  final String? detail;

  AuditLogEntry({
    required this.timestamp,
    required this.action,
    required this.target,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'action': action,
    'target': target,
    'detail': detail,
  };

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
    timestamp: json['timestamp'] as String,
    action: json['action'] as String,
    target: json['target'] as String,
    detail: json['detail'] as String?,
  );
}

/// 操作ログサービス
/// データの追加・編集・削除などの操作履歴を記録する
class AuditLogService {
  static const _key = 'drone_app_audit_log';
  static const _maxEntries = 500; // 最大保持件数

  /// 操作ログを記録
  static Future<void> log({
    required AuditAction action,
    required String target,
    String? detail,
  }) async {
    final entry = AuditLogEntry(
      timestamp: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      action: action.label,
      target: target,
      detail: detail,
    );

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_key) ?? [];

    // 先頭に追加（新しいものが先）
    rawList.insert(0, jsonEncode(entry.toJson()));

    // 最大件数を超えたら古いものを削除
    if (rawList.length > _maxEntries) {
      rawList.removeRange(_maxEntries, rawList.length);
    }

    await prefs.setStringList(_key, rawList);
  }

  /// 全操作ログを取得（新しい順）
  static Future<List<AuditLogEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_key) ?? [];

    return rawList.map((raw) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AuditLogEntry.fromJson(json);
    }).toList();
  }

  /// 操作ログをクリア
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// ログ件数を取得
  static Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).length;
  }
}
