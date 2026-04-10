import 'package:csv/csv.dart';
import '../database/local_storage.dart';
import '../database/flight_log_storage.dart';

/// CSV変換サービス
/// 機体データ・操縦者データのCSV変換を担当
class CsvService {
  // ---- 機体データ CSV ----

  /// 機体データのCSVヘッダー
  static const aircraftCsvHeaders = [
    '登録番号',
    '航空機タイプ',
    '製造メーカー',
    'モデル名',
    'シリアルナンバー',
    '最大離陸重量(kg)',
  ];

  /// 機体リストをCSV文字列に変換
  static String aircraftsToCSv(List<AircraftData> aircrafts) {
    final rows = <List<dynamic>>[
      aircraftCsvHeaders,
      ...aircrafts.map((a) => [
            a.registrationNumber,
            a.aircraftType,
            a.manufacturer ?? '',
            a.modelName ?? '',
            a.serialNumber ?? '',
            a.maxTakeoffWeight?.toString() ?? '',
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// CSV文字列を機体データのMapリストにパース
  /// 既存データとのID衝突を避けるため、IDは含めない
  static List<Map<String, String>> parseAircraftCsv(String csvString) {
    final rows = const CsvToListConverter().convert(csvString);
    if (rows.length < 2) return []; // ヘッダーのみまたは空

    final results = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      // 登録番号が空の行はスキップ
      final regNum = row[0].toString().trim();
      if (regNum.isEmpty) continue;

      results.add({
        'registrationNumber': regNum,
        'aircraftType': row.length > 1 ? row[1].toString().trim() : 'マルチローター',
        'manufacturer': row.length > 2 ? row[2].toString().trim() : '',
        'modelName': row.length > 3 ? row[3].toString().trim() : '',
        'serialNumber': row.length > 4 ? row[4].toString().trim() : '',
        'maxTakeoffWeight': row.length > 5 ? row[5].toString().trim() : '',
      });
    }
    return results;
  }

  // ---- 操縦者データ CSV ----

  /// 操縦者データのCSVヘッダー
  static const pilotCsvHeaders = [
    '名前',
    '免許証番号',
    '免許種類',
    '免許有効期限',
    '所属組織',
    '連絡先',
  ];

  /// 操縦者リストをCSV文字列に変換
  static String pilotsToCsv(List<PilotData> pilots) {
    final rows = <List<dynamic>>[
      pilotCsvHeaders,
      ...pilots.map((p) => [
            p.name,
            p.licenseNumber ?? '',
            p.licenseType ?? '',
            p.licenseExpiry ?? '',
            p.organization ?? '',
            p.contact ?? '',
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// CSV文字列を操縦者データのMapリストにパース
  static List<Map<String, String>> parsePilotCsv(String csvString) {
    final rows = const CsvToListConverter().convert(csvString);
    if (rows.length < 2) return [];

    final results = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final name = row[0].toString().trim();
      if (name.isEmpty) continue;

      results.add({
        'name': name,
        'licenseNumber': row.length > 1 ? row[1].toString().trim() : '',
        'licenseType': row.length > 2 ? row[2].toString().trim() : '',
        'licenseExpiry': row.length > 3 ? row[3].toString().trim() : '',
        'organization': row.length > 4 ? row[4].toString().trim() : '',
        'contact': row.length > 5 ? row[5].toString().trim() : '',
      });
    }
    return results;
  }

  // ---- 飛行記録データ CSV ----

  /// 飛行記録のCSVヘッダー
  static const flightCsvHeaders = [
    '飛行日',
    '離陸時刻',
    '着陸時刻',
    '飛行時間(分)',
    '離陸場所',
    '着陸場所',
    '飛行目的',
    '飛行空域',
    '最大高度',
    '天候',
    '風速',
    '気温',
    '備考',
    '機体ID',
    '機体登録番号',
    '機種名',
    '操縦者ID',
    '操縦者名',
  ];

  /// 飛行記録リストをCSV文字列に変換
  /// [aircraftNames] 機体IDから登録番号へのマップ
  /// [aircraftModels] 機体IDから機種名へのマップ
  /// [pilotNames] 操縦者IDから名前へのマップ
  static String flightsToCsv(
    List<FlightRecordData> flights, {
    Map<int, String> aircraftNames = const {},
    Map<int, String> aircraftModels = const {},
    Map<int, String> pilotNames = const {},
  }) {
    final rows = <List<dynamic>>[
      flightCsvHeaders,
      ...flights.map((f) => [
            f.flightDate,
            f.takeoffTime ?? '',
            f.landingTime ?? '',
            f.flightDuration?.toString() ?? '',
            f.takeoffLocation ?? '',
            f.landingLocation ?? '',
            f.flightPurpose ?? '',
            f.flightArea ?? '',
            f.maxAltitude ?? '',
            f.weather ?? '',
            f.windSpeed ?? '',
            f.temperature ?? '',
            f.notes ?? '',
            f.aircraftId,
            aircraftNames[f.aircraftId] ?? '',
            aircraftModels[f.aircraftId] ?? '',
            f.pilotId,
            pilotNames[f.pilotId] ?? '',
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// CSV文字列を飛行記録データのMapリストにパース
  /// ヘッダー行を読み取り、列名からデータをマッピングする
  static List<Map<String, String>> parseFlightCsv(String csvString) {
    final rows = const CsvToListConverter().convert(csvString);
    if (rows.length < 2) return []; // ヘッダーのみまたは空

    // ヘッダー行からインデックスマップを構築
    final headerRow = rows[0].map((e) => e.toString().trim()).toList();
    final colIndex = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      colIndex[headerRow[i]] = i;
    }

    String get(List<dynamic> row, String colName) {
      final idx = colIndex[colName];
      if (idx == null || idx >= row.length) return '';
      return row[idx].toString().trim();
    }

    final results = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      // 飛行日が空の行はスキップ
      final flightDate = get(row, '飛行日');
      if (flightDate.isEmpty) continue;

      results.add({
        'flightDate': flightDate,
        'takeoffTime': get(row, '離陸時刻'),
        'landingTime': get(row, '着陸時刻'),
        'flightDuration': get(row, '飛行時間(分)'),
        'takeoffLocation': get(row, '離陸場所'),
        'landingLocation': get(row, '着陸場所'),
        'flightPurpose': get(row, '飛行目的'),
        'flightArea': get(row, '飛行空域'),
        'maxAltitude': get(row, '最大高度'),
        'weather': get(row, '天候'),
        'windSpeed': get(row, '風速'),
        'temperature': get(row, '気温'),
        'notes': get(row, '備考'),
        'aircraftId': get(row, '機体ID'),
        'pilotId': get(row, '操縦者ID'),
      });
    }
    return results;
  }

  // ---- 日常点検データ CSV（様式2） ----

  /// 日常点検のCSVヘッダー
  static const inspectionCsvHeaders = [
    '点検日',
    '機体ID',
    '点検者ID',
    'フレーム',
    'プロペラ',
    'モーター',
    'バッテリー',
    'コントローラー',
    'GPS',
    'カメラ',
    '通信機器',
    '総合結果',
    '監督者',
    '備考',
  ];

  /// 日常点検リストをCSV文字列に変換
  static String inspectionsToCsv(List<DailyInspectionData> inspections) {
    String okNg(bool value) => value ? 'OK' : 'NG';
    final rows = <List<dynamic>>[
      inspectionCsvHeaders,
      ...inspections.map((i) => [
            i.inspectionDate,
            i.aircraftId,
            i.inspectorId,
            okNg(i.frameCheck),
            okNg(i.propellerCheck),
            okNg(i.motorCheck),
            okNg(i.batteryCheck),
            okNg(i.controllerCheck),
            okNg(i.gpsCheck),
            okNg(i.cameraCheck),
            okNg(i.communicationCheck),
            i.overallResult,
            i.supervisorNames.join('、'),
            i.notes ?? '',
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  // ---- 整備記録データ CSV（様式3） ----

  /// 整備記録のCSVヘッダー
  static const maintenanceCsvHeaders = [
    '整備日',
    '機体ID',
    '整備者ID',
    '整備種別',
    '整備内容',
    '交換部品',
    '結果',
    '次回整備予定日',
    '監督者',
    '備考',
  ];

  /// 整備記録リストをCSV文字列に変換
  static String maintenancesToCsv(List<MaintenanceRecordData> maintenances) {
    final rows = <List<dynamic>>[
      maintenanceCsvHeaders,
      ...maintenances.map((m) => [
            m.maintenanceDate,
            m.aircraftId,
            m.maintainerId,
            m.maintenanceType,
            m.description ?? '',
            m.partsReplaced ?? '',
            m.result ?? '',
            m.nextMaintenanceDate ?? '',
            m.supervisorNames.join('、'),
            m.notes ?? '',
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }
}
