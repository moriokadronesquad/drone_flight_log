import '../database/flight_log_storage.dart';

/// 機体の安全・整備状態を判定するサービス
///
/// 飛行記録フォームで機体を選択した際に、
/// その機体の最新点検・整備状況を確認して警告を表示する
class AircraftSafetyStatus {
  /// 最終点検日
  final String? lastInspectionDate;
  /// 最終点検結果
  final String? lastInspectionResult;
  /// 最終点検からの経過日数
  final int? daysSinceInspection;
  /// 最終整備日
  final String? lastMaintenanceDate;
  /// 最終整備結果
  final String? lastMaintenanceResult;
  /// 次回整備予定日
  final String? nextMaintenanceDate;
  /// 次回整備予定日までの残日数（マイナスは期限超過）
  final int? daysUntilNextMaintenance;
  /// 総飛行回数（この機体）
  final int totalFlights;
  /// 総飛行時間（分）
  final int totalFlightMinutes;
  /// 安全レベル: ok, warning, danger
  final String safetyLevel;
  /// 警告メッセージ一覧
  final List<String> warnings;

  const AircraftSafetyStatus({
    this.lastInspectionDate,
    this.lastInspectionResult,
    this.daysSinceInspection,
    this.lastMaintenanceDate,
    this.lastMaintenanceResult,
    this.nextMaintenanceDate,
    this.daysUntilNextMaintenance,
    this.totalFlights = 0,
    this.totalFlightMinutes = 0,
    this.safetyLevel = 'ok',
    this.warnings = const [],
  });
}

class AircraftSafetyService {
  /// 指定機体の安全状態を取得
  static Future<AircraftSafetyStatus> checkAircraftSafety({
    required int aircraftId,
    required FlightLogStorage storage,
  }) async {
    final warnings = <String>[];
    var safetyLevel = 'ok';
    final now = DateTime.now();

    // 全データ取得
    final inspections = await storage.getAllInspections();
    final maintenances = await storage.getAllMaintenances();
    final flights = await storage.getAllFlights();

    // この機体の記録のみ抽出
    final acInspections = inspections
        .where((i) => i.aircraftId == aircraftId)
        .toList()
      ..sort((a, b) => b.inspectionDate.compareTo(a.inspectionDate));

    final acMaintenances = maintenances
        .where((m) => m.aircraftId == aircraftId)
        .toList()
      ..sort((a, b) => b.maintenanceDate.compareTo(a.maintenanceDate));

    final acFlights = flights.where((f) => f.aircraftId == aircraftId).toList();

    // 総飛行統計
    final totalFlights = acFlights.length;
    final totalMinutes = acFlights.fold<int>(
      0,
      (sum, f) => sum + (f.flightDuration ?? 0),
    );

    // 最新点検チェック
    String? lastInspDate;
    String? lastInspResult;
    int? daysSinceInsp;

    if (acInspections.isNotEmpty) {
      final latest = acInspections.first;
      lastInspDate = latest.inspectionDate;
      lastInspResult = latest.overallResult;
      final inspDate = DateTime.tryParse(latest.inspectionDate);
      if (inspDate != null) {
        daysSinceInsp = now.difference(inspDate).inDays;
      }

      // 最終点検が不合格・要整備
      if (latest.overallResult == '不合格') {
        warnings.add('最終点検結果が「不合格」です');
        safetyLevel = 'danger';
      } else if (latest.overallResult == '要整備') {
        warnings.add('最終点検で「要整備」の判定です');
        if (safetyLevel != 'danger') safetyLevel = 'warning';
      }

      // 点検から7日以上経過
      if (daysSinceInsp != null && daysSinceInsp > 7) {
        warnings.add('最終点検から$daysSinceInsp日経過しています');
        if (safetyLevel != 'danger') safetyLevel = 'warning';
      }
    } else {
      warnings.add('この機体の点検記録がありません');
      if (safetyLevel != 'danger') safetyLevel = 'warning';
    }

    // 最新整備チェック
    String? lastMaintDate;
    String? lastMaintResult;
    String? nextMaintDate;
    int? daysUntilNext;

    if (acMaintenances.isNotEmpty) {
      final latest = acMaintenances.first;
      lastMaintDate = latest.maintenanceDate;
      lastMaintResult = latest.result;
      nextMaintDate = latest.nextMaintenanceDate;

      // 最終整備が要追加整備
      if (latest.result == '要追加整備') {
        warnings.add('最終整備が「要追加整備」です');
        if (safetyLevel != 'danger') safetyLevel = 'warning';
      } else if (latest.result == '不可') {
        warnings.add('最終整備結果が「不可」です。飛行しないでください');
        safetyLevel = 'danger';
      }

      // 次回整備予定日チェック
      if (nextMaintDate != null) {
        final nextDate = DateTime.tryParse(nextMaintDate);
        if (nextDate != null) {
          daysUntilNext = nextDate.difference(now).inDays;
          if (daysUntilNext < 0) {
            warnings.add('次回整備予定日を${-daysUntilNext}日超過しています');
            safetyLevel = 'danger';
          } else if (daysUntilNext <= 7) {
            warnings.add('次回整備予定日まであと$daysUntilNext日です');
            if (safetyLevel != 'danger') safetyLevel = 'warning';
          }
        }
      }
    }

    return AircraftSafetyStatus(
      lastInspectionDate: lastInspDate,
      lastInspectionResult: lastInspResult,
      daysSinceInspection: daysSinceInsp,
      lastMaintenanceDate: lastMaintDate,
      lastMaintenanceResult: lastMaintResult,
      nextMaintenanceDate: nextMaintDate,
      daysUntilNextMaintenance: daysUntilNext,
      totalFlights: totalFlights,
      totalFlightMinutes: totalMinutes,
      safetyLevel: safetyLevel,
      warnings: warnings,
    );
  }
}
