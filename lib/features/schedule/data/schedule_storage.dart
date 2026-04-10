import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 飛行予定カテゴリ
enum ScheduleCategory {
  /// 許可承認の申請予定
  permitApplication('許可承認の申請予定', 'permit'),
  /// 飛行計画の通報予定
  flightPlanReport('飛行計画の通報予定', 'plan'),
  /// 飛行日誌の作成予定
  flightLogCreation('飛行日誌の作成予定', 'log'),
  /// その他の予定
  other('その他の予定', 'other');

  final String label;
  final String value;
  const ScheduleCategory(this.label, this.value);

  static ScheduleCategory fromValue(String value) {
    return ScheduleCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ScheduleCategory.other,
    );
  }
}

/// リマインダー設定
enum ReminderOption {
  none(0, 'なし'),
  min30(30, '30分前'),
  hour1(60, '1時間前'),
  hour3(180, '3時間前'),
  day1(1440, '1日前'),
  day3(4320, '3日前'),
  week1(10080, '1週間前');

  final int minutes;
  final String label;
  const ReminderOption(this.minutes, this.label);

  static ReminderOption fromMinutes(int minutes) {
    return ReminderOption.values.firstWhere(
      (e) => e.minutes == minutes,
      orElse: () => ReminderOption.none,
    );
  }
}

/// 飛行予定データクラス
class FlightScheduleData {
  final int id;
  final String category;
  final String title;
  final String? description;
  final String scheduledDate;
  final String? scheduledTime;
  final int reminderMinutes;
  final String? googleCalendarEventId;
  final bool isCompleted;
  final String createdAt;
  final String updatedAt;

  FlightScheduleData({
    required this.id,
    required this.category,
    required this.title,
    this.description,
    required this.scheduledDate,
    this.scheduledTime,
    this.reminderMinutes = 60,
    this.googleCalendarEventId,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'title': title,
    'description': description,
    'scheduledDate': scheduledDate,
    'scheduledTime': scheduledTime,
    'reminderMinutes': reminderMinutes,
    'googleCalendarEventId': googleCalendarEventId,
    'isCompleted': isCompleted,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory FlightScheduleData.fromJson(Map<String, dynamic> json) =>
      FlightScheduleData(
        id: json['id'] as int,
        category: json['category'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        scheduledDate: json['scheduledDate'] as String,
        scheduledTime: json['scheduledTime'] as String?,
        reminderMinutes: json['reminderMinutes'] as int? ?? 60,
        googleCalendarEventId: json['googleCalendarEventId'] as String?,
        isCompleted: json['isCompleted'] as bool? ?? false,
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );

  /// copyWith でフィールドを部分更新した新しいインスタンスを返す
  FlightScheduleData copyWith({
    int? id,
    String? category,
    String? title,
    String? description,
    String? scheduledDate,
    String? scheduledTime,
    int? reminderMinutes,
    String? googleCalendarEventId,
    bool? isCompleted,
    String? createdAt,
    String? updatedAt,
  }) {
    return FlightScheduleData(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      googleCalendarEventId: googleCalendarEventId ?? this.googleCalendarEventId,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 飛行予定ストレージ（SharedPreferences ベース）
class ScheduleStorage {
  late SharedPreferences _prefs;
  int _nextId = 1;
  List<FlightScheduleData> _schedules = [];

  static const _storageKey = 'drone_app_schedules';

  /// 初期化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    try {
      final content = _prefs.getString(_storageKey);
      if (content != null && content.isNotEmpty) {
        final json = jsonDecode(content) as Map<String, dynamic>;
        final list = json['items'] as List<dynamic>? ?? [];
        _schedules = list
            .map((item) =>
                FlightScheduleData.fromJson(item as Map<String, dynamic>))
            .toList();
        _nextId = (json['nextId'] as int?) ??
            (_schedules.isEmpty
                ? 1
                : _schedules.map((s) => s.id).reduce((a, b) => a > b ? a : b) +
                    1);
      }
    } catch (e) {
      _schedules = [];
      _nextId = 1;
    }
  }

  Future<void> _save() async {
    final json = jsonEncode({
      'items': _schedules.map((s) => s.toJson()).toList(),
      'nextId': _nextId,
    });
    await _prefs.setString(_storageKey, json);
  }

  /// 全件取得（日付降順）
  Future<List<FlightScheduleData>> getAllSchedules() async {
    final sorted = List<FlightScheduleData>.from(_schedules);
    sorted.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    return sorted;
  }

  /// カテゴリ別フィルタ取得
  Future<List<FlightScheduleData>> getSchedulesByCategory(String category) async {
    final filtered = _schedules.where((s) => s.category == category).toList();
    filtered.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    return filtered;
  }

  /// 未完了の予定を日付昇順で取得
  Future<List<FlightScheduleData>> getUpcomingSchedules() async {
    final now = DateTime.now().toIso8601String().substring(0, 10);
    final upcoming = _schedules.where((s) =>
      !s.isCompleted && s.scheduledDate.compareTo(now) >= 0
    ).toList();
    upcoming.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return upcoming;
  }

  /// 新規作成
  Future<int> createSchedule({
    required String category,
    required String title,
    String? description,
    required String scheduledDate,
    String? scheduledTime,
    int reminderMinutes = 60,
    String? googleCalendarEventId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _nextId;
    _nextId++;

    _schedules.add(FlightScheduleData(
      id: id,
      category: category,
      title: title,
      description: description,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      reminderMinutes: reminderMinutes,
      googleCalendarEventId: googleCalendarEventId,
      createdAt: now,
      updatedAt: now,
    ));
    await _save();
    return id;
  }

  /// 完了状態の切り替え
  Future<bool> toggleComplete(int id) async {
    final index = _schedules.indexWhere((s) => s.id == id);
    if (index == -1) return false;

    final schedule = _schedules[index];
    _schedules[index] = schedule.copyWith(
      isCompleted: !schedule.isCompleted,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _save();
    return true;
  }

  /// GoogleカレンダーイベントIDを更新
  Future<bool> updateGoogleCalendarId(int id, String eventId) async {
    final index = _schedules.indexWhere((s) => s.id == id);
    if (index == -1) return false;

    final schedule = _schedules[index];
    _schedules[index] = schedule.copyWith(
      googleCalendarEventId: eventId,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _save();
    return true;
  }

  /// 削除
  Future<bool> deleteSchedule(int id) async {
    final index = _schedules.indexWhere((s) => s.id == id);
    if (index == -1) return false;
    _schedules.removeAt(index);
    await _save();
    return true;
  }

  /// 予定の件数取得（ホーム画面の統計用）
  int get totalCount => _schedules.length;
  int get upcomingCount {
    final now = DateTime.now().toIso8601String().substring(0, 10);
    return _schedules.where((s) =>
      !s.isCompleted && s.scheduledDate.compareTo(now) >= 0
    ).length;
  }
}
