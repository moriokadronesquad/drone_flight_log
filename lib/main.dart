import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_scheduler_service.dart';
import 'core/services/auto_backup_service.dart';

/// ドローン飛行日誌アプリのエントリーポイント
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ローカル通知の初期化（スマホのみ。Webでは非対応のためスキップ）
  if (!kIsWeb) {
    try {
      await NotificationService.init();
      await NotificationService.requestPermission();
      // 起動時に全リマインダーを同期
      await ReminderSchedulerService.syncAllReminders();
    } catch (e) {
      debugPrint('通知サービスの初期化をスキップしました: $e');
    }
  }

  // 起動時に自動バックアップをチェック
  try {
    final backed = await AutoBackupService.checkAndBackup();
    if (backed) {
      debugPrint('起動時の自動バックアップが完了しました');
    }
  } catch (e) {
    debugPrint('自動バックアップのチェックをスキップしました: $e');
  }

  runApp(
    const ProviderScope(
      child: DroneFlightLogApp(),
    ),
  );
}
