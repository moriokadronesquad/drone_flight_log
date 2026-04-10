import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../features/schedule/data/schedule_storage.dart';

/// ローカル通知サービス
///
/// 飛行予定のリマインダーをスマホに直接プッシュ通知する。
/// Googleカレンダー経由の通知と併用可能。
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// 初期化（アプリ起動時に1回呼び出す）
  /// Web環境では動作しない（flutter_local_notifications非対応）
  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      debugPrint('NotificationService: Web環境のためスキップ');
      return;
    }

    // タイムゾーン初期化
    tz_data.initializeTimeZones();
    // 日本時間
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    // Android設定
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS設定
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    debugPrint('NotificationService: 初期化完了');
  }

  /// 通知タップ時のコールバック
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('通知タップ: ${response.payload}');
    // 将来的にはここで飛行予定ページへのナビゲーションを実装
  }

  /// 通知権限をリクエスト（Android 13+）
  static Future<bool> requestPermission() async {
    // Android
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// 飛行予定のリマインダー通知をスケジュール
  ///
  /// 予定日時の [reminderMinutes] 分前に通知を送信
  static Future<void> scheduleReminder({
    required FlightScheduleData schedule,
  }) async {
    if (!_initialized) await init();

    // 通知時刻を計算
    final scheduledDateTime = _parseScheduleDateTime(schedule);
    if (scheduledDateTime == null) return;

    final notifyAt = scheduledDateTime.subtract(
      Duration(minutes: schedule.reminderMinutes),
    );

    // 過去の時刻なら通知しない
    if (notifyAt.isBefore(DateTime.now())) {
      debugPrint('NotificationService: 通知時刻が過去のためスキップ (id=${schedule.id})');
      return;
    }

    final tzNotifyAt = tz.TZDateTime.from(notifyAt, tz.local);

    // カテゴリラベル
    final categoryLabel = ScheduleCategory.fromValue(schedule.category).label;

    // Android通知チャンネル
    const androidDetails = AndroidNotificationDetails(
      'drone_schedule_reminder',
      '飛行予定リマインダー',
      channelDescription: '飛行予定のリマインダー通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      schedule.id, // 通知ID = 予定ID
      '【ドローン】$categoryLabel',
      '${schedule.title}\n${_formatDateTime(schedule)}',
      tzNotifyAt,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'schedule_${schedule.id}',
    );

    debugPrint('NotificationService: 通知をスケジュール '
        '(id=${schedule.id}, at=$tzNotifyAt)');
  }

  /// スケジュール済み通知をキャンセル
  static Future<void> cancelReminder(int scheduleId) async {
    if (!_initialized) await init();
    await _plugin.cancel(scheduleId);
    debugPrint('NotificationService: 通知キャンセル (id=$scheduleId)');
  }

  /// 全通知をキャンセル
  static Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
  }

  /// テスト用：即時通知を送信
  static Future<void> showTestNotification() async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'drone_schedule_reminder',
      '飛行予定リマインダー',
      channelDescription: '飛行予定のリマインダー通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      0,
      '【ドローン飛行日誌】テスト通知',
      '通知が正常に動作しています',
      details,
    );
  }

  // ---- ヘルパー ----

  /// 予定日時をDateTimeにパース
  static DateTime? _parseScheduleDateTime(FlightScheduleData schedule) {
    try {
      if (schedule.scheduledTime != null && schedule.scheduledTime!.isNotEmpty) {
        return DateTime.parse(
          '${schedule.scheduledDate}T${schedule.scheduledTime}:00',
        );
      } else {
        // 時刻未設定の場合は当日9:00をデフォルトに
        return DateTime.parse('${schedule.scheduledDate}T09:00:00');
      }
    } catch (e) {
      debugPrint('NotificationService: 日時パースエラー: $e');
      return null;
    }
  }

  /// 日時フォーマット
  static String _formatDateTime(FlightScheduleData schedule) {
    final date = schedule.scheduledDate;
    final time = schedule.scheduledTime;
    if (time != null && time.isNotEmpty) {
      return '$date $time';
    }
    return date;
  }
}
