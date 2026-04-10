import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/schedule/data/schedule_storage.dart';
import 'notification_service.dart';

/// リマインダースケジューラーサービス
/// アプリ起動時や設定変更時に、未来の飛行予定の通知を一括登録する
class ReminderSchedulerService {
  static const _enabledKey = 'drone_app_reminder_enabled';

  /// リマインダー通知が有効かどうかを取得
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true; // デフォルトON
  }

  /// リマインダー通知の有効/無効を切り替え
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (enabled) {
      // ONにしたら全リマインダーを再登録
      await syncAllReminders();
    } else {
      // OFFにしたら全キャンセル
      await NotificationService.cancelAll();
      debugPrint('ReminderScheduler: 全リマインダーをキャンセルしました');
    }
  }

  /// 全ての未来の飛行予定のリマインダーを再登録
  /// アプリ起動時に呼ぶことで、通知が確実にスケジュールされる
  static Future<void> syncAllReminders() async {
    if (kIsWeb) return; // Web非対応

    final enabled = await isEnabled();
    if (!enabled) return;

    try {
      // まず全キャンセル
      await NotificationService.cancelAll();

      // 全予定を取得
      final storage = ScheduleStorage();
      final schedules = await storage.getAllSchedules();

      var scheduled = 0;
      for (final schedule in schedules) {
        // 完了済み・リマインダーなし はスキップ
        if (schedule.isCompleted) continue;
        if (schedule.reminderMinutes <= 0) continue;

        // 未来の予定のみ
        try {
          final dateStr = schedule.scheduledDate;
          final date = DateTime.parse(dateStr);
          if (date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
            continue;
          }
        } catch (_) {
          continue;
        }

        await NotificationService.scheduleReminder(schedule: schedule);
        scheduled++;
      }

      debugPrint('ReminderScheduler: $scheduled件のリマインダーを登録しました');
    } catch (e) {
      debugPrint('ReminderScheduler: 同期エラー: $e');
    }
  }
}
