import '../database/flight_log_storage.dart';

/// 操縦者のステータス情報
class PilotStatusInfo {
  /// 最終飛行日
  final String? lastFlightDate;
  /// 最終飛行日からの経過日数
  final int? daysSinceLastFlight;
  /// この操縦者の総飛行回数
  final int totalFlights;
  /// この操縦者の総飛行時間（分）
  final int totalFlightMinutes;
  /// 免許有効期限
  final String? licenseExpiry;
  /// 免許有効期限までの残日数（マイナスは期限切れ）
  final int? daysUntilLicenseExpiry;
  /// ステータスレベル: ok, warning, danger
  final String statusLevel;
  /// 警告メッセージ一覧
  final List<String> warnings;

  const PilotStatusInfo({
    this.lastFlightDate,
    this.daysSinceLastFlight,
    this.totalFlights = 0,
    this.totalFlightMinutes = 0,
    this.licenseExpiry,
    this.daysUntilLicenseExpiry,
    this.statusLevel = 'ok',
    this.warnings = const [],
  });
}

class PilotStatusService {
  /// 指定操縦者のステータスを取得
  static Future<PilotStatusInfo> checkPilotStatus({
    required int pilotId,
    required String? licenseExpiry,
    required FlightLogStorage storage,
  }) async {
    final warnings = <String>[];
    var level = 'ok';
    final now = DateTime.now();

    // 全飛行記録を取得してこの操縦者のものを抽出
    final flights = await storage.getAllFlights();
    final pilotFlights = flights
        .where((f) => f.pilotId == pilotId)
        .toList()
      ..sort((a, b) => b.flightDate.compareTo(a.flightDate));

    final totalFlights = pilotFlights.length;
    final totalMinutes = pilotFlights.fold<int>(
      0,
      (sum, f) => sum + (f.flightDuration ?? 0),
    );

    // 最終飛行日
    String? lastFlightDate;
    int? daysSinceLast;
    if (pilotFlights.isNotEmpty) {
      lastFlightDate = pilotFlights.first.flightDate;
      final lastDate = DateTime.tryParse(lastFlightDate);
      if (lastDate != null) {
        daysSinceLast = now.difference(lastDate).inDays;
        // 90日以上飛行なし → 注意
        if (daysSinceLast > 90) {
          warnings.add('$daysSinceLast日間飛行がありません（技能維持に注意）');
          if (level != 'danger') level = 'warning';
        } else if (daysSinceLast > 30) {
          warnings.add('$daysSinceLast日間飛行がありません');
        }
      }
    } else {
      warnings.add('飛行記録がありません');
    }

    // 免許有効期限
    int? daysUntilExpiry;
    if (licenseExpiry != null && licenseExpiry.isNotEmpty) {
      final expiryDate = DateTime.tryParse(licenseExpiry);
      if (expiryDate != null) {
        daysUntilExpiry = expiryDate.difference(now).inDays;
        if (daysUntilExpiry < 0) {
          warnings.add('免許が${-daysUntilExpiry}日前に期限切れです');
          level = 'danger';
        } else if (daysUntilExpiry <= 30) {
          warnings.add('免許有効期限まであと$daysUntilExpiry日です');
          if (level != 'danger') level = 'warning';
        } else if (daysUntilExpiry <= 90) {
          warnings.add('免許有効期限まであと$daysUntilExpiry日です');
        }
      }
    }

    return PilotStatusInfo(
      lastFlightDate: lastFlightDate,
      daysSinceLastFlight: daysSinceLast,
      totalFlights: totalFlights,
      totalFlightMinutes: totalMinutes,
      licenseExpiry: licenseExpiry,
      daysUntilLicenseExpiry: daysUntilExpiry,
      statusLevel: level,
      warnings: warnings,
    );
  }
}
