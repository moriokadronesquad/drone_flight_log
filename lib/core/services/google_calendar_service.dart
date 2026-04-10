import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import '../../features/schedule/data/schedule_storage.dart';

/// Googleカレンダー連携サービス
///
/// Google Sign-In → OAuth認証 → Calendar API v3 を使って
/// 飛行予定をGoogleカレンダーに登録・削除する
class GoogleCalendarService {
  /// Google Sign-In インスタンス
  /// Web版とモバイル版で設定が異なるため、scopesを指定
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      gcal.CalendarApi.calendarEventsScope,
    ],
  );

  /// 現在のサインイン状態
  static GoogleSignInAccount? _currentUser;

  /// サインイン済みかどうか
  static bool get isSignedIn => _currentUser != null;

  /// 現在のユーザー名
  static String? get userName => _currentUser?.displayName;

  /// 現在のユーザーメール
  static String? get userEmail => _currentUser?.email;

  /// Google サインイン（初回認証）
  /// 成功: true, 失敗/キャンセル: false
  static Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser != null;
    } catch (e) {
      debugPrint('Google Sign-In エラー: $e');
      return false;
    }
  }

  /// サイレントサインイン（以前に認証済みの場合、自動的にサインイン）
  static Future<bool> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser != null;
    } catch (e) {
      debugPrint('サイレントサインイン エラー: $e');
      return false;
    }
  }

  /// サインアウト
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// 認証済みHTTPクライアントを取得
  static Future<http.Client?> _getAuthClient() async {
    if (_currentUser == null) return null;

    try {
      final authHeaders = await _currentUser!.authHeaders;
      return _GoogleAuthClient(authHeaders);
    } catch (e) {
      debugPrint('認証ヘッダー取得エラー: $e');
      return null;
    }
  }

  /// Googleカレンダーにイベントを作成
  /// 成功: イベントID, 失敗: null
  static Future<String?> createEvent({
    required FlightScheduleData schedule,
  }) async {
    // サインインチェック
    if (!isSignedIn) {
      final success = await signIn();
      if (!success) return null;
    }

    final client = await _getAuthClient();
    if (client == null) return null;

    try {
      final calendarApi = gcal.CalendarApi(client);

      // 予定日時の設定
      final dateStr = schedule.scheduledDate;
      final timeStr = schedule.scheduledTime;

      gcal.EventDateTime start;
      gcal.EventDateTime end;

      if (timeStr != null && timeStr.isNotEmpty) {
        // 時刻指定ありの場合
        final startDateTime = DateTime.parse('${dateStr}T$timeStr:00');
        final endDateTime = startDateTime.add(const Duration(hours: 1));
        start = gcal.EventDateTime(dateTime: startDateTime);
        end = gcal.EventDateTime(dateTime: endDateTime);
      } else {
        // 終日イベント
        start = gcal.EventDateTime(date: DateTime.parse(dateStr));
        end = gcal.EventDateTime(
          date: DateTime.parse(dateStr).add(const Duration(days: 1)),
        );
      }

      // カテゴリラベルの取得
      final categoryLabel = ScheduleCategory.fromValue(schedule.category).label;

      // イベント作成
      final event = gcal.Event(
        summary: '【ドローン】${schedule.title}',
        description: _buildDescription(schedule, categoryLabel),
        start: start,
        end: end,
        reminders: _buildReminders(schedule.reminderMinutes),
      );

      final createdEvent = await calendarApi.events.insert(
        event,
        'primary', // ユーザーのメインカレンダー
      );

      return createdEvent.id;
    } catch (e) {
      debugPrint('カレンダーイベント作成エラー: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Googleカレンダーのイベントを削除
  static Future<bool> deleteEvent(String eventId) async {
    if (!isSignedIn) {
      final success = await signInSilently();
      if (!success) return false;
    }

    final client = await _getAuthClient();
    if (client == null) return false;

    try {
      final calendarApi = gcal.CalendarApi(client);
      await calendarApi.events.delete('primary', eventId);
      return true;
    } catch (e) {
      debugPrint('カレンダーイベント削除エラー: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// イベントの説明文を作成
  static String _buildDescription(
    FlightScheduleData schedule,
    String categoryLabel,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('📋 カテゴリ: $categoryLabel');
    if (schedule.description != null && schedule.description!.isNotEmpty) {
      buffer.writeln('📝 詳細: ${schedule.description}');
    }
    buffer.writeln('');
    buffer.writeln('--- ドローン飛行日誌アプリから登録 ---');
    return buffer.toString();
  }

  /// リマインダー設定を作成
  static gcal.EventReminders? _buildReminders(int reminderMinutes) {
    if (reminderMinutes <= 0) {
      return gcal.EventReminders(useDefault: true);
    }

    return gcal.EventReminders(
      useDefault: false,
      overrides: [
        gcal.EventReminder(
          method: 'popup',
          minutes: reminderMinutes,
        ),
      ],
    );
  }
}

/// Google認証ヘッダーを付与するHTTPクライアント
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
