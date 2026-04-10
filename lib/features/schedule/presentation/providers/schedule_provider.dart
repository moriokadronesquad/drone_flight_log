import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/schedule_storage.dart';

/// ScheduleStorage のシングルトンインスタンスプロバイダ
final scheduleStorageProvider = Provider<ScheduleStorage>((ref) {
  final storage = ScheduleStorage();
  return storage;
});

/// 飛行予定一覧プロバイダ（全件）
final scheduleListProvider = FutureProvider<List<FlightScheduleData>>((ref) async {
  final storage = ref.read(scheduleStorageProvider);
  await storage.init();
  return storage.getAllSchedules();
});

/// 直近の飛行予定プロバイダ（未完了のみ・日付昇順）
final upcomingScheduleProvider = FutureProvider<List<FlightScheduleData>>((ref) async {
  final storage = ref.read(scheduleStorageProvider);
  await storage.init();
  return storage.getUpcomingSchedules();
});

/// カテゴリフィルター用の状態プロバイダ
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// フィルタ適用後の予定一覧
final filteredScheduleListProvider = FutureProvider<List<FlightScheduleData>>((ref) async {
  final storage = ref.read(scheduleStorageProvider);
  await storage.init();
  final category = ref.watch(selectedCategoryProvider);

  if (category != null) {
    return storage.getSchedulesByCategory(category);
  }
  return storage.getAllSchedules();
});
