import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/flight_log_storage.dart';
import '../../../../core/database/local_storage.dart';
import '../../../flight_log/presentation/providers/flight_log_provider.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';

/// 飛行統計データ
class FlightStatistics {
  final int totalFlights;
  final int totalFlightMinutes;
  final int totalAircrafts;
  final int totalPilots;
  final int totalInspections;
  final int totalMaintenances;
  final Map<String, int> flightsByMonth;
  final Map<String, int> flightsByAircraft;
  final Map<String, int> flightsByPilot;
  final Map<String, int> flightsByPurpose;
  final Map<String, int> flightsByArea;
  final Map<String, int> flightsByWeather;
  final List<FlightRecordData> recentFlights;

  const FlightStatistics({
    this.totalFlights = 0,
    this.totalFlightMinutes = 0,
    this.totalAircrafts = 0,
    this.totalPilots = 0,
    this.totalInspections = 0,
    this.totalMaintenances = 0,
    this.flightsByMonth = const {},
    this.flightsByAircraft = const {},
    this.flightsByPilot = const {},
    this.flightsByPurpose = const {},
    this.flightsByArea = const {},
    this.flightsByWeather = const {},
    this.recentFlights = const [],
  });
}

/// 飛行統計データプロバイダ
/// すべての飛行データを集計して統計情報を返す
final flightStatisticsProvider = FutureProvider<FlightStatistics>((ref) async {
  final flights = await ref.watch(flightListProvider.future);
  final inspections = await ref.watch(inspectionListProvider.future);
  final maintenances = await ref.watch(maintenanceListProvider.future);
  final aircrafts = await ref.watch(aircraftListProvider.future);
  final pilots = await ref.watch(pilotListProvider.future);
  final storage = await ref.watch(localStorageProvider.future);

  // 機体名のマップを作成（ID→名前）
  final aircraftNames = <int, String>{};
  for (final a in storage.getAllAircraftsSync()) {
    aircraftNames[a.id] = a.modelName ?? a.registrationNumber;
  }

  // 操縦者名のマップを作成（ID→名前）
  final pilotNames = <int, String>{};
  for (final p in storage.getAllPilotsSync()) {
    pilotNames[p.id] = p.name;
  }

  // 総飛行時間
  var totalMinutes = 0;
  for (final f in flights) {
    if (f.flightDuration != null) {
      totalMinutes += f.flightDuration!;
    }
  }

  // 月別飛行回数
  final flightsByMonth = <String, int>{};
  for (final f in flights) {
    final month = f.flightDate.length >= 7
        ? f.flightDate.substring(0, 7) // "2025-01"
        : f.flightDate;
    flightsByMonth[month] = (flightsByMonth[month] ?? 0) + 1;
  }
  // ソート
  final sortedMonths = Map.fromEntries(
    flightsByMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );

  // 機体別飛行回数
  final flightsByAircraft = <String, int>{};
  for (final f in flights) {
    final name = aircraftNames[f.aircraftId] ?? '不明 (ID:${f.aircraftId})';
    flightsByAircraft[name] = (flightsByAircraft[name] ?? 0) + 1;
  }

  // 操縦者別飛行回数
  final flightsByPilot = <String, int>{};
  for (final f in flights) {
    final name = pilotNames[f.pilotId] ?? '不明 (ID:${f.pilotId})';
    flightsByPilot[name] = (flightsByPilot[name] ?? 0) + 1;
  }

  // 目的別飛行回数
  final flightsByPurpose = <String, int>{};
  for (final f in flights) {
    final purpose = f.flightPurpose ?? '未設定';
    if (purpose.isNotEmpty) {
      flightsByPurpose[purpose] = (flightsByPurpose[purpose] ?? 0) + 1;
    }
  }

  // 空域別飛行回数
  final flightsByArea = <String, int>{};
  for (final f in flights) {
    final area = f.flightArea ?? '未設定';
    if (area.isNotEmpty) {
      flightsByArea[area] = (flightsByArea[area] ?? 0) + 1;
    }
  }

  // 天候別飛行回数
  final flightsByWeather = <String, int>{};
  for (final f in flights) {
    final weather = f.weather ?? '未記録';
    if (weather.isNotEmpty) {
      flightsByWeather[weather] = (flightsByWeather[weather] ?? 0) + 1;
    }
  }

  // 最近の飛行（新しい順に5件）
  final sortedFlights = List<FlightRecordData>.from(flights)
    ..sort((a, b) => b.flightDate.compareTo(a.flightDate));
  final recentFlights = sortedFlights.take(5).toList();

  return FlightStatistics(
    totalFlights: flights.length,
    totalFlightMinutes: totalMinutes,
    totalAircrafts: aircrafts.length,
    totalPilots: pilots.length,
    totalInspections: inspections.length,
    totalMaintenances: maintenances.length,
    flightsByMonth: sortedMonths,
    flightsByAircraft: flightsByAircraft,
    flightsByPilot: flightsByPilot,
    flightsByPurpose: flightsByPurpose,
    flightsByArea: flightsByArea,
    flightsByWeather: flightsByWeather,
    recentFlights: recentFlights,
  );
});
