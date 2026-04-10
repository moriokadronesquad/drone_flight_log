import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/google_calendar_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/schedule_storage.dart';
import '../providers/schedule_provider.dart';

/// 飛行予定登録フォームページ
class ScheduleFormPage extends ConsumerStatefulWidget {
  const ScheduleFormPage({super.key});

  @override
  ConsumerState<ScheduleFormPage> createState() => _ScheduleFormPageState();
}

class _ScheduleFormPageState extends ConsumerState<ScheduleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  ScheduleCategory _selectedCategory = ScheduleCategory.permitApplication;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _selectedTime;
  ReminderOption _selectedReminder = ReminderOption.hour1;
  bool _addToGoogleCalendar = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('飛行予定の登録'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // カテゴリ選択
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '予定カテゴリ',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...ScheduleCategory.values.map((cat) => RadioListTile<ScheduleCategory>(
                        value: cat,
                        groupValue: _selectedCategory,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                              // カテゴリに応じてデフォルトタイトルを設定
                              if (_titleController.text.isEmpty) {
                                _titleController.text = _getDefaultTitle(value);
                              }
                            });
                          }
                        },
                        title: Row(
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
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // タイトル
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル *',
                  hintText: '予定のタイトルを入力',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 詳細説明
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '詳細説明（任意）',
                  hintText: '補足情報を入力',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // 予定日
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: const Text('予定日'),
                  subtitle: Text(
                    DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _pickDate(),
                ),
              ),

              const SizedBox(height: 8),

              // 予定時刻
              Card(
                child: ListTile(
                  leading: const Icon(Icons.access_time, color: Colors.orange),
                  title: const Text('予定時刻（任意）'),
                  subtitle: Text(
                    _selectedTime != null
                        ? _selectedTime!.format(context)
                        : '未設定',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _selectedTime != null ? FontWeight.bold : FontWeight.normal,
                      color: _selectedTime != null ? null : Colors.grey,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedTime != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _selectedTime = null;
                            });
                          },
                        ),
                      const Icon(Icons.edit),
                    ],
                  ),
                  onTap: () => _pickTime(),
                ),
              ),

              const SizedBox(height: 16),

              // リマインダー設定
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_outlined, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text(
                            'リマインダー',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ReminderOption>(
                        initialValue: _selectedReminder,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: ReminderOption.values.map((option) => DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedReminder = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Googleカレンダー連携トグル
              Card(
                color: _addToGoogleCalendar ? Colors.blue[50] : Colors.grey[100],
                child: SwitchListTile(
                  secondary: Icon(
                    Icons.calendar_month,
                    color: _addToGoogleCalendar ? Colors.blue[700] : Colors.grey,
                  ),
                  title: Text(
                    'Googleカレンダーに追加',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _addToGoogleCalendar ? Colors.blue[700] : Colors.grey[600],
                    ),
                  ),
                  subtitle: Text(
                    _addToGoogleCalendar
                        ? 'リマインダー付きでGoogleカレンダーにも登録します'
                        : 'アプリ内のみに保存します',
                    style: TextStyle(
                      fontSize: 12,
                      color: _addToGoogleCalendar ? Colors.blue[600] : Colors.grey[500],
                    ),
                  ),
                  value: _addToGoogleCalendar,
                  onChanged: (value) {
                    setState(() {
                      _addToGoogleCalendar = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 24),

              // 登録ボタン
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSchedule,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? '保存中...' : '予定を登録'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 日付選択
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ja'),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  /// 時刻選択
  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  /// 予定を保存
  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final storage = ref.read(scheduleStorageProvider);
      await storage.init();

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      String? timeStr;
      if (_selectedTime != null) {
        timeStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
            '${_selectedTime!.minute.toString().padLeft(2, '0')}';
      }

      final scheduleId = await storage.createSchedule(
        category: _selectedCategory.value,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        scheduledDate: dateStr,
        scheduledTime: timeStr,
        reminderMinutes: _selectedReminder.minutes,
      );

      // Googleカレンダーに登録
      String? googleResult;
      if (_addToGoogleCalendar) {
        // 作成した予定データを取得
        final allSchedules = await storage.getAllSchedules();
        final createdSchedule = allSchedules.firstWhere(
          (s) => s.id == scheduleId,
        );

        final eventId = await GoogleCalendarService.createEvent(
          schedule: createdSchedule,
        );

        if (eventId != null) {
          await storage.updateGoogleCalendarId(scheduleId, eventId);
          googleResult = 'success';
        } else {
          googleResult = 'failed';
        }
      }

      // ローカル通知もスケジュール（スマホに直接通知）
      if (_selectedReminder.minutes > 0) {
        try {
          final allSchedules = await storage.getAllSchedules();
          final saved = allSchedules.firstWhere((s) => s.id == scheduleId);
          await NotificationService.scheduleReminder(schedule: saved);
        } catch (e) {
          debugPrint('ローカル通知スケジュール失敗: $e');
        }
      }

      if (mounted) {
        var message = '飛行予定を登録しました';
        Color bgColor = Colors.green;

        if (_addToGoogleCalendar) {
          if (googleResult == 'success') {
            message = '飛行予定を登録し、Googleカレンダーにも追加しました';
          } else {
            message = '飛行予定を登録しました（Googleカレンダーへの追加は失敗しました）';
            bgColor = Colors.orange;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// カテゴリに応じたデフォルトタイトル
  String _getDefaultTitle(ScheduleCategory category) {
    switch (category) {
      case ScheduleCategory.permitApplication:
        return '飛行許可承認申請';
      case ScheduleCategory.flightPlanReport:
        return '飛行計画通報（FISS）';
      case ScheduleCategory.flightLogCreation:
        return '飛行日誌作成';
      case ScheduleCategory.other:
        return '';
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
