import 'package:intl/intl.dart';
import '../database/flight_log_storage.dart';

/// 飛行記録サマリー生成サービス
/// テキスト形式のサマリーを生成し、コピーや共有に利用する
class FlightSummaryService {
  /// 単一飛行記録のテキストサマリーを生成
  static String generateFlightSummary({
    required FlightRecordData flight,
    String? aircraftName,
    String? pilotName,
  }) {
    final duration = flight.flightDuration ?? 0;
    final hours = duration ~/ 60;
    final mins = duration % 60;
    final timeStr = hours > 0 ? '$hours時間$mins分' : '$mins分';

    final lines = <String>[
      '【飛行記録】',
      '飛行番号: FLT-${flight.id.toString().padLeft(4, '0')}',
      '日付: ${flight.flightDate}',
      '機体: ${aircraftName ?? "機体ID:${flight.aircraftId}"}',
      '操縦者: ${pilotName ?? "操縦者ID:${flight.pilotId}"}',
      '離陸: ${flight.takeoffTime ?? "-"} / 着陸: ${flight.landingTime ?? "-"}',
      '飛行時間: $timeStr',
      '場所: ${flight.takeoffLocation ?? "-"}',
      '目的: ${flight.flightPurpose ?? "-"}',
    ];

    if (flight.notes != null && flight.notes!.isNotEmpty) {
      lines.add('備考: ${flight.notes}');
    }

    lines.add('');
    lines.add('--- ドローンログより出力 ---');

    return lines.join('\n');
  }

  /// 期間サマリーのテキストを生成
  static String generatePeriodSummary({
    required List<FlightRecordData> flights,
    required String startDate,
    required String endDate,
    Map<int, String>? aircraftNames,
    Map<int, String>? pilotNames,
  }) {
    final totalMinutes = flights.fold<int>(0, (sum, f) => sum + (f.flightDuration ?? 0));
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    // 機体別集計
    final aircraftCount = <int, int>{};
    for (final f in flights) {
      aircraftCount[f.aircraftId] = (aircraftCount[f.aircraftId] ?? 0) + 1;
    }

    // 操縦者別集計
    final pilotCount = <int, int>{};
    for (final f in flights) {
      pilotCount[f.pilotId] = (pilotCount[f.pilotId] ?? 0) + 1;
    }

    // 場所別集計
    final locationCount = <String, int>{};
    for (final f in flights) {
      final loc = f.takeoffLocation ?? '不明';
      locationCount[loc] = (locationCount[loc] ?? 0) + 1;
    }

    final lines = <String>[
      '【飛行記録サマリー】',
      '期間: $startDate ～ $endDate',
      '総飛行回数: ${flights.length}回',
      '総飛行時間: $hours時間$mins分',
      '',
      '■ 機体別飛行回数:',
    ];

    aircraftCount.forEach((id, count) {
      final name = aircraftNames?[id] ?? '機体ID:$id';
      lines.add('  $name: $count回');
    });

    lines.add('');
    lines.add('■ 操縦者別飛行回数:');
    pilotCount.forEach((id, count) {
      final name = pilotNames?[id] ?? '操縦者ID:$id';
      lines.add('  $name: $count回');
    });

    lines.add('');
    lines.add('■ 飛行場所:');
    final sortedLocations = locationCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedLocations.take(5)) {
      lines.add('  ${entry.key}: ${entry.value}回');
    }

    lines.add('');
    lines.add('出力日: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}');
    lines.add('--- ドローンログより出力 ---');

    return lines.join('\n');
  }
}
