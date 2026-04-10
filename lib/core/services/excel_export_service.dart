import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../database/flight_log_storage.dart';
import '../database/local_storage.dart';

/// Excelエクスポートサービス
///
/// 飛行記録・点検記録・整備記録を
/// 列幅・ヘッダー色付き・シート分けの見やすいExcel形式で出力する
class ExcelExportService {
  /// 全データを1つのExcelファイルにエクスポート
  ///
  /// シート構成:
  /// - 飛行記録（様式1）
  /// - 日常点検（様式2）
  /// - 整備記録（様式3）
  /// - 機体一覧
  /// - 操縦者一覧
  static Future<Uint8List> exportAll({
    required List<FlightRecordData> flights,
    required List<DailyInspectionData> inspections,
    required List<MaintenanceRecordData> maintenances,
    required List<AircraftData> aircrafts,
    required List<PilotData> pilots,
  }) async {
    final excel = Excel.createExcel();

    // 機体名・操縦者名マップ
    final aircraftMap = <int, String>{};
    for (final a in aircrafts) {
      aircraftMap[a.id] = '${a.registrationNumber} ${a.modelName ?? ""}';
    }
    final pilotMap = <int, String>{};
    for (final p in pilots) {
      pilotMap[p.id] = p.name;
    }

    // ── 飛行記録シート ──
    _buildFlightSheet(excel, flights, aircraftMap, pilotMap);

    // ── 日常点検シート ──
    _buildInspectionSheet(excel, inspections, aircraftMap, pilotMap);

    // ── 整備記録シート ──
    _buildMaintenanceSheet(excel, maintenances, aircraftMap, pilotMap);

    // ── 機体一覧シート ──
    _buildAircraftSheet(excel, aircrafts);

    // ── 操縦者一覧シート ──
    _buildPilotSheet(excel, pilots);

    // デフォルトシートを削除
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes!);
  }

  /// ヘッダースタイル
  static CellStyle get _headerStyle => CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Center,
  );

  /// データセルスタイル
  static CellStyle get _dataStyle => CellStyle(
    fontSize: 10,
  );

  /// 飛行記録シート
  static void _buildFlightSheet(
    Excel excel,
    List<FlightRecordData> flights,
    Map<int, String> aircraftMap,
    Map<int, String> pilotMap,
  ) {
    final sheet = excel['飛行記録'];

    final headers = [
      'No.', '飛行番号', '飛行日', '離陸時刻', '着陸時刻', '飛行時間(分)',
      '操縦者', '使用機体', '離陸場所', '着陸場所',
      '飛行目的', '飛行区域', '最大高度(m)', '天候', '風速(m/s)', '気温(℃)',
      'バッテリー前(%)', 'バッテリー後(%)', '備考',
    ];

    // ヘッダー行
    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    // データ行
    for (var i = 0; i < flights.length; i++) {
      final f = flights[i];
      final row = i + 1;
      final flightNo = 'FLT-${f.id.toString().padLeft(4, '0')}';

      final values = [
        '${i + 1}',
        flightNo,
        f.flightDate,
        f.takeoffTime ?? '',
        f.landingTime ?? '',
        f.flightDuration?.toString() ?? '',
        pilotMap[f.pilotId] ?? 'ID:${f.pilotId}',
        aircraftMap[f.aircraftId] ?? 'ID:${f.aircraftId}',
        f.takeoffLocation ?? '',
        f.landingLocation ?? '',
        f.flightPurpose ?? '',
        f.flightArea ?? '',
        f.maxAltitude ?? '',
        f.weather ?? '',
        f.windSpeed ?? '',
        f.temperature ?? '',
        f.batteryBefore?.toString() ?? '',
        f.batteryAfter?.toString() ?? '',
        f.notes ?? '',
      ];

      for (var col = 0; col < values.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = TextCellValue(values[col]);
        cell.cellStyle = _dataStyle;
      }
    }

    // 列幅の設定
    sheet.setColumnWidth(0, 6);   // No.
    sheet.setColumnWidth(1, 12);  // 飛行番号
    sheet.setColumnWidth(2, 12);  // 飛行日
    sheet.setColumnWidth(3, 10);  // 離陸
    sheet.setColumnWidth(4, 10);  // 着陸
    sheet.setColumnWidth(5, 10);  // 時間
    sheet.setColumnWidth(6, 12);  // 操縦者
    sheet.setColumnWidth(7, 20);  // 機体
    sheet.setColumnWidth(8, 20);  // 離陸場所
    sheet.setColumnWidth(9, 20);  // 着陸場所
    sheet.setColumnWidth(10, 12); // 目的
    sheet.setColumnWidth(11, 16); // 区域
    sheet.setColumnWidth(12, 10); // 高度
    sheet.setColumnWidth(13, 8);  // 天候
    sheet.setColumnWidth(14, 8);  // 風速
    sheet.setColumnWidth(15, 8);  // 気温
    sheet.setColumnWidth(16, 10); // バッテリー前
    sheet.setColumnWidth(17, 10); // バッテリー後
    sheet.setColumnWidth(18, 30); // 備考
  }

  /// 日常点検シート
  static void _buildInspectionSheet(
    Excel excel,
    List<DailyInspectionData> inspections,
    Map<int, String> aircraftMap,
    Map<int, String> pilotMap,
  ) {
    final sheet = excel['日常点検'];

    final headers = [
      'No.', '点検日', '機体', '点検者',
      '機体', 'ﾌﾟﾛﾍﾟﾗ', 'ﾓｰﾀｰ', 'ﾊﾞｯﾃﾘ', '送信機', 'GPS', 'ｶﾒﾗ', '通信',
      '総合結果', '備考',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    for (var i = 0; i < inspections.length; i++) {
      final insp = inspections[i];
      final row = i + 1;
      String check(bool v) => v ? 'OK' : 'NG';

      final values = [
        '${i + 1}',
        insp.inspectionDate,
        aircraftMap[insp.aircraftId] ?? 'ID:${insp.aircraftId}',
        pilotMap[insp.inspectorId] ?? 'ID:${insp.inspectorId}',
        check(insp.frameCheck),
        check(insp.propellerCheck),
        check(insp.motorCheck),
        check(insp.batteryCheck),
        check(insp.controllerCheck),
        check(insp.gpsCheck),
        check(insp.cameraCheck),
        check(insp.communicationCheck),
        insp.overallResult,
        insp.notes ?? '',
      ];

      for (var col = 0; col < values.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = TextCellValue(values[col]);
        cell.cellStyle = _dataStyle;
      }
    }

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 12);
    for (var i = 4; i <= 11; i++) {
      sheet.setColumnWidth(i, 8);
    }
    sheet.setColumnWidth(12, 10);
    sheet.setColumnWidth(13, 30);
  }

  /// 整備記録シート
  static void _buildMaintenanceSheet(
    Excel excel,
    List<MaintenanceRecordData> maintenances,
    Map<int, String> aircraftMap,
    Map<int, String> pilotMap,
  ) {
    final sheet = excel['整備記録'];

    final headers = [
      'No.', '整備日', '機体', '整備者', '種別',
      '整備内容', '交換部品', '結果', '次回予定日', '監督者', '備考',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    for (var i = 0; i < maintenances.length; i++) {
      final m = maintenances[i];
      final row = i + 1;

      final values = [
        '${i + 1}',
        m.maintenanceDate,
        aircraftMap[m.aircraftId] ?? 'ID:${m.aircraftId}',
        pilotMap[m.maintainerId] ?? 'ID:${m.maintainerId}',
        m.maintenanceType,
        m.description ?? '',
        m.partsReplaced ?? '',
        m.result ?? '',
        m.nextMaintenanceDate ?? '',
        m.supervisorNames.join(', '),
        m.notes ?? '',
      ];

      for (var col = 0; col < values.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = TextCellValue(values[col]);
        cell.cellStyle = _dataStyle;
      }
    }

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 12);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 30);
    sheet.setColumnWidth(6, 20);
    sheet.setColumnWidth(7, 10);
    sheet.setColumnWidth(8, 12);
    sheet.setColumnWidth(9, 16);
    sheet.setColumnWidth(10, 30);
  }

  /// 機体一覧シート
  static void _buildAircraftSheet(Excel excel, List<AircraftData> aircrafts) {
    final sheet = excel['機体一覧'];

    final headers = [
      'No.', '登録番号', '航空機タイプ', '製造メーカー',
      'モデル名', 'シリアルナンバー', '最大離陸重量(kg)',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    for (var i = 0; i < aircrafts.length; i++) {
      final a = aircrafts[i];
      final row = i + 1;

      final values = [
        '${i + 1}',
        a.registrationNumber,
        a.aircraftType,
        a.manufacturer ?? '',
        a.modelName ?? '',
        a.serialNumber ?? '',
        a.maxTakeoffWeight?.toString() ?? '',
      ];

      for (var col = 0; col < values.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = TextCellValue(values[col]);
        cell.cellStyle = _dataStyle;
      }
    }

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 16);
    sheet.setColumnWidth(2, 14);
    sheet.setColumnWidth(3, 16);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 18);
    sheet.setColumnWidth(6, 14);
  }

  /// 操縦者一覧シート
  static void _buildPilotSheet(Excel excel, List<PilotData> pilots) {
    final sheet = excel['操縦者一覧'];

    final headers = [
      'No.', '氏名', '免許番号', '免許種別', '免許有効期限',
      '所属組織', '連絡先', '技能証明書番号',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = _headerStyle;
    }

    for (var i = 0; i < pilots.length; i++) {
      final p = pilots[i];
      final row = i + 1;

      final values = [
        '${i + 1}',
        p.name,
        p.licenseNumber ?? '',
        p.licenseType ?? '',
        p.licenseExpiry ?? '',
        p.organization ?? '',
        p.contact ?? '',
        p.certificateNumber ?? '',
      ];

      for (var col = 0; col < values.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = TextCellValue(values[col]);
        cell.cellStyle = _dataStyle;
      }
    }

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 14);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 16);
    sheet.setColumnWidth(6, 16);
    sheet.setColumnWidth(7, 18);
  }
}
