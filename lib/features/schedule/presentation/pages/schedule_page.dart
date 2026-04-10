import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/google_calendar_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/schedule_storage.dart';
import '../providers/schedule_provider.dart';

/// 飛行予定一覧ページ
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(filteredScheduleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('飛行予定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          // カテゴリフィルタ
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'カテゴリ絞り込み',
            onSelected: (value) {
              setState(() {
                _selectedCategory = value;
              });
              ref.read(selectedCategoryProvider.notifier).state = value;
              ref.invalidate(filteredScheduleListProvider);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('すべて表示'),
              ),
              const PopupMenuDivider(),
              ...ScheduleCategory.values.map((cat) => PopupMenuItem(
                value: cat.value,
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(cat.value),
                      size: 20,
                      color: _getCategoryColor(cat.value),
                    ),
                    const SizedBox(width: 8),
                    Text(cat.label),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // フィルター表示
          if (_selectedCategory != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _getCategoryColor(_selectedCategory!).withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(_selectedCategory!),
                    size: 18,
                    color: _getCategoryColor(_selectedCategory!),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ScheduleCategory.fromValue(_selectedCategory!).label,
                    style: TextStyle(
                      color: _getCategoryColor(_selectedCategory!),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                      });
                      ref.read(selectedCategoryProvider.notifier).state = null;
                      ref.invalidate(filteredScheduleListProvider);
                    },
                    child: const Text('クリア'),
                  ),
                ],
              ),
            ),

          // 予定一覧
          Expanded(
            child: schedulesAsync.when(
              data: (schedules) {
                if (schedules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          '飛行予定はありません',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '右下の＋ボタンから新しい予定を登録できます',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return _ScheduleCard(
                      schedule: schedule,
                      onToggleComplete: () => _toggleComplete(schedule),
                      onDelete: () => _confirmDelete(schedule),
                      onTapCalendar: () => _addToGoogleCalendar(schedule),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('エラーが発生しました: $e'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>('/schedule/new');
          if (result == true) {
            ref.invalidate(filteredScheduleListProvider);
            ref.invalidate(scheduleListProvider);
            ref.invalidate(upcomingScheduleProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 完了状態を切り替え
  Future<void> _toggleComplete(FlightScheduleData schedule) async {
    final storage = ref.read(scheduleStorageProvider);
    await storage.init();
    await storage.toggleComplete(schedule.id);
    ref.invalidate(filteredScheduleListProvider);
    ref.invalidate(scheduleListProvider);
    ref.invalidate(upcomingScheduleProvider);
  }

  /// 削除確認ダイアログ
  Future<void> _confirmDelete(FlightScheduleData schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('予定の削除'),
        content: Text('「${schedule.title}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // ローカル通知もキャンセル
      await NotificationService.cancelReminder(schedule.id);

      // Googleカレンダーのイベントも削除
      if (schedule.googleCalendarEventId != null) {
        await GoogleCalendarService.deleteEvent(schedule.googleCalendarEventId!);
      }

      final storage = ref.read(scheduleStorageProvider);
      await storage.init();
      await storage.deleteSchedule(schedule.id);
      ref.invalidate(filteredScheduleListProvider);
      ref.invalidate(scheduleListProvider);
      ref.invalidate(upcomingScheduleProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('予定を削除しました')),
        );
      }
    }
  }

  /// Googleカレンダーにイベントを追加
  Future<void> _addToGoogleCalendar(FlightScheduleData schedule) async {
    // 既に登録済みの場合
    if (schedule.googleCalendarEventId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この予定は既にGoogleカレンダーに登録済みです')),
      );
      return;
    }

    // ローディング表示
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Googleカレンダーに登録中...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      // Google Sign-In → Calendar API でイベント作成
      final eventId = await GoogleCalendarService.createEvent(schedule: schedule);

      // SnackBarを消す
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (eventId != null) {
        // ストレージにイベントIDを保存
        final storage = ref.read(scheduleStorageProvider);
        await storage.init();
        await storage.updateGoogleCalendarId(schedule.id, eventId);
        ref.invalidate(filteredScheduleListProvider);
        ref.invalidate(scheduleListProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Googleカレンダーに登録しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Googleカレンダーへの登録に失敗しました。\nGoogleアカウントにサインインしてください。'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'permit':
        return Icons.verified;
      case 'plan':
        return Icons.map;
      case 'log':
        return Icons.book;
      case 'other':
        return Icons.event;
      default:
        return Icons.event;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'permit':
        return Colors.red;
      case 'plan':
        return Colors.blue;
      case 'log':
        return Colors.green;
      case 'other':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

/// 飛行予定カード
class _ScheduleCard extends StatelessWidget {
  final FlightScheduleData schedule;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;
  final VoidCallback onTapCalendar;

  const _ScheduleCard({
    required this.schedule,
    required this.onToggleComplete,
    required this.onDelete,
    required this.onTapCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final categoryEnum = ScheduleCategory.fromValue(schedule.category);
    final isOverdue = !schedule.isCompleted &&
        schedule.scheduledDate.compareTo(
          DateTime.now().toIso8601String().substring(0, 10),
        ) < 0;

    // 日付フォーマット
    var formattedDate = schedule.scheduledDate;
    try {
      final date = DateTime.parse(schedule.scheduledDate);
      formattedDate = DateFormat('yyyy/MM/dd (E)', 'ja').format(date);
    } catch (_) {
      // パース失敗時はそのまま表示
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverdue
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      child: Opacity(
        opacity: schedule.isCompleted ? 0.6 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー行：カテゴリ + アクション
              Row(
                children: [
                  // カテゴリバッジ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(schedule.category).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIcon(schedule.category),
                          size: 14,
                          color: _getCategoryColor(schedule.category),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          categoryEnum.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getCategoryColor(schedule.category),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isOverdue) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '期限超過',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Googleカレンダー登録ボタン
                  IconButton(
                    icon: Icon(
                      schedule.googleCalendarEventId != null
                          ? Icons.event_available
                          : Icons.calendar_month,
                      color: schedule.googleCalendarEventId != null
                          ? Colors.green
                          : Colors.grey,
                      size: 20,
                    ),
                    tooltip: schedule.googleCalendarEventId != null
                        ? 'カレンダー登録済み'
                        : 'Googleカレンダーに追加',
                    onPressed: onTapCalendar,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),

                  // 削除ボタン
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    tooltip: '削除',
                    onPressed: onDelete,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // タイトル
              Row(
                children: [
                  // 完了チェックボックス
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: schedule.isCompleted,
                      onChanged: (_) => onToggleComplete(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schedule.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: schedule.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),

              // 詳細説明
              if (schedule.description != null && schedule.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Text(
                    schedule.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // 日付・時刻・リマインダー情報
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    if (schedule.scheduledTime != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        schedule.scheduledTime!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                    if (schedule.reminderMinutes > 0) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.notifications_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        ReminderOption.fromMinutes(schedule.reminderMinutes).label,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'permit':
        return Icons.verified;
      case 'plan':
        return Icons.map;
      case 'log':
        return Icons.book;
      case 'other':
        return Icons.event;
      default:
        return Icons.event;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'permit':
        return Colors.red;
      case 'plan':
        return Colors.blue;
      case 'log':
        return Colors.green;
      case 'other':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
