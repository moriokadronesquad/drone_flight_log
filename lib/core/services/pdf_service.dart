import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../database/flight_log_storage.dart';

/// PDF生成サービス
/// 国土交通省の無人航空機飛行日誌様式に準拠したPDFを生成する
class PdfService {
  /// 様式1: 飛行実績記録PDF生成
  ///
  /// [flights] 飛行記録リスト
  /// [aircraftName] 機体名（登録番号 + モデル名）
  /// [aircraftInfo] 機体詳細情報マップ（manufacturer, model, weight等）
  /// [pilotNames] パイロットID→名前のマップ
  static Future<Uint8List> generateFlightRecordPdf({
    required List<FlightRecordData> flights,
    String? aircraftName,
    Map<String, String>? aircraftInfo,
    Map<int, String>? pilotNames,
  }) async {
    final pdf = pw.Document();

    // 日本語フォント（PDFライブラリのデフォルトフォントを使用）
    // 注: 実際の運用では Noto Sans JP などの日本語対応フォントをバンドルする必要があります
    final titleStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
    );
    const normalStyle = pw.TextStyle(fontSize: 9);
    const smallStyle = pw.TextStyle(fontSize: 8);
    final boldStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    // 出力日
    final outputDate = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

    // ページ分割（1ページあたり最大20件）
    const recordsPerPage = 20;
    final totalPages = (flights.length / recordsPerPage).ceil();

    for (var page = 0; page < totalPages; page++) {
      final startIdx = page * recordsPerPage;
      final endIdx = (startIdx + recordsPerPage > flights.length)
          ? flights.length
          : startIdx + recordsPerPage;
      final pageFlights = flights.sublist(startIdx, endIdx);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ヘッダー
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Unmanned Aircraft Flight Record (様式1)',
                      style: titleStyle,
                    ),
                    pw.Text(
                      'Page ${page + 1} / $totalPages',
                      style: smallStyle,
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),

                // 機体情報セクション
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Aircraft / 機体', style: boldStyle),
                            pw.Text(
                              aircraftName ?? '-',
                              style: normalStyle,
                            ),
                          ],
                        ),
                      ),
                      if (aircraftInfo != null) ...[
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Manufacturer / 製造者', style: boldStyle),
                              pw.Text(
                                aircraftInfo['manufacturer'] ?? '-',
                                style: normalStyle,
                              ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Weight / 重量', style: boldStyle),
                              pw.Text(
                                aircraftInfo['weight'] ?? '-',
                                style: normalStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // 飛行記録テーブル
                pw.TableHelper.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(
                    color: PdfColors.grey600,
                    width: 0.5,
                  ),
                  headerStyle: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey700,
                  ),
                  cellStyle: smallStyle,
                  cellAlignments: {
                    0: pw.Alignment.center,  // No.
                    1: pw.Alignment.center,  // Date
                    2: pw.Alignment.center,  // Takeoff
                    3: pw.Alignment.center,  // Landing
                    4: pw.Alignment.center,  // Duration
                    5: pw.Alignment.centerLeft, // Pilot
                    6: pw.Alignment.centerLeft, // Location
                    7: pw.Alignment.centerLeft, // Purpose
                    8: pw.Alignment.center,  // Area
                    9: pw.Alignment.center,  // Alt
                    10: pw.Alignment.center, // Weather
                    11: pw.Alignment.center, // Wind
                    12: pw.Alignment.centerLeft, // Notes
                  },
                  columnWidths: {
                    0: const pw.FixedColumnWidth(28),
                    1: const pw.FixedColumnWidth(62),
                    2: const pw.FixedColumnWidth(38),
                    3: const pw.FixedColumnWidth(38),
                    4: const pw.FixedColumnWidth(32),
                    5: const pw.FixedColumnWidth(56),
                    6: const pw.FixedColumnWidth(100),
                    7: const pw.FixedColumnWidth(52),
                    8: const pw.FixedColumnWidth(60),
                    9: const pw.FixedColumnWidth(30),
                    10: const pw.FixedColumnWidth(32),
                    11: const pw.FixedColumnWidth(28),
                    12: const pw.FlexColumnWidth(),
                  },
                  headers: [
                    'No.',
                    'Date\n日付',
                    'T/O\n離陸',
                    'LDG\n着陸',
                    'Min\n分',
                    'Pilot\n操縦者',
                    'Location\n離陸場所',
                    'Purpose\n目的',
                    'Area\n飛行区域',
                    'Alt\nm',
                    'WX\n天候',
                    'Wind\nm/s',
                    'Notes\n備考',
                  ],
                  data: pageFlights.asMap().entries.map((entry) {
                    final idx = startIdx + entry.key + 1;
                    final f = entry.value;
                    final pilotName = pilotNames?[f.pilotId] ??
                        '#${f.pilotId}';

                    // Phase 4.5: 備考に拡張情報を集約
                    final noteParts = <String>[];
                    if (f.batteryBefore != null || f.batteryAfter != null) {
                      noteParts.add('Batt:${f.batteryBefore ?? "?"}%->${f.batteryAfter ?? "?"}%');
                    }
                    if (f.permitNumber != null && f.permitNumber!.isNotEmpty) {
                      noteParts.add('Permit:${f.permitNumber}');
                    }
                    if (f.supervisorNames.isNotEmpty) {
                      noteParts.add('Sup:${f.supervisorNames.join(",")}');
                    }
                    if (f.notes != null && f.notes!.isNotEmpty) {
                      noteParts.add(f.notes!);
                    }

                    return [
                      '$idx',
                      f.flightDate,
                      f.takeoffTime ?? '-',
                      f.landingTime ?? '-',
                      f.flightDuration?.toString() ?? '-',
                      pilotName,
                      f.takeoffLocation ?? '-',
                      f.flightPurpose ?? '-',
                      f.flightArea ?? '-',
                      f.maxAltitude ?? '-',
                      f.weather ?? '-',
                      f.windSpeed ?? '-',
                      noteParts.join(' / '),
                    ];
                  }).toList(),
                ),

                pw.Spacer(),

                // フッター
                pw.Divider(color: PdfColors.grey400),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total flights: ${flights.length} / '
                      'Total time: ${_totalMinutes(flights)} min',
                      style: boldStyle,
                    ),
                    pw.Text(
                      'Generated: $outputDate',
                      style: smallStyle,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// 様式2: 日常点検記録PDF生成
  static Future<Uint8List> generateInspectionPdf({
    required List<DailyInspectionData> inspections,
    String? aircraftName,
    Map<int, String>? inspectorNames,
  }) async {
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
    );
    const smallStyle = pw.TextStyle(fontSize: 8);
    final boldStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    final outputDate = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

    const recordsPerPage = 25;
    final totalPages = (inspections.length / recordsPerPage).ceil();

    for (var page = 0; page < totalPages; page++) {
      final startIdx = page * recordsPerPage;
      final endIdx = (startIdx + recordsPerPage > inspections.length)
          ? inspections.length
          : startIdx + recordsPerPage;
      final pageInspections = inspections.sublist(startIdx, endIdx);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Daily Inspection Record (様式2)',
                      style: titleStyle,
                    ),
                    pw.Text('Page ${page + 1} / $totalPages', style: smallStyle),
                  ],
                ),
                pw.SizedBox(height: 4),

                if (aircraftName != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey700),
                    ),
                    child: pw.Text('Aircraft / 機体: $aircraftName', style: boldStyle),
                  ),
                pw.SizedBox(height: 8),

                // 点検テーブル
                pw.TableHelper.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(
                    color: PdfColors.grey600,
                    width: 0.5,
                  ),
                  headerStyle: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey700,
                  ),
                  cellStyle: smallStyle,
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.center,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                    5: pw.Alignment.center,
                    6: pw.Alignment.center,
                    7: pw.Alignment.center,
                    8: pw.Alignment.center,
                    9: pw.Alignment.center,
                    10: pw.Alignment.center,
                    11: pw.Alignment.center,
                    12: pw.Alignment.centerLeft,
                  },
                  headers: [
                    'No.',
                    'Date\n日付',
                    'Inspector\n点検者',
                    'Frame\n機体',
                    'Prop\nﾌﾟﾛﾍﾟﾗ',
                    'Motor\nﾓｰﾀｰ',
                    'Batt\nﾊﾞｯﾃﾘ',
                    'Ctrl\n送信機',
                    'GPS',
                    'Cam\nｶﾒﾗ',
                    'Comm\n通信',
                    'Result\n結果',
                    'Notes\n備考',
                  ],
                  data: pageInspections.asMap().entries.map((entry) {
                    final idx = startIdx + entry.key + 1;
                    final i = entry.value;
                    final inspector = inspectorNames?[i.inspectorId] ??
                        '#${i.inspectorId}';

                    String check(bool v) => v ? 'OK' : 'NG';

                    return [
                      '$idx',
                      i.inspectionDate,
                      inspector,
                      check(i.frameCheck),
                      check(i.propellerCheck),
                      check(i.motorCheck),
                      check(i.batteryCheck),
                      check(i.controllerCheck),
                      check(i.gpsCheck),
                      check(i.cameraCheck),
                      check(i.communicationCheck),
                      i.overallResult,
                      i.notes ?? '',
                    ];
                  }).toList(),
                ),

                pw.Spacer(),

                pw.Divider(color: PdfColors.grey400),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total inspections: ${inspections.length}',
                      style: boldStyle,
                    ),
                    pw.Text('Generated: $outputDate', style: smallStyle),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// 様式3: 整備記録PDF生成
  static Future<Uint8List> generateMaintenancePdf({
    required List<MaintenanceRecordData> maintenances,
    String? aircraftName,
    Map<int, String>? maintainerNames,
  }) async {
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
    );
    const smallStyle = pw.TextStyle(fontSize: 8);
    final boldStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    final outputDate = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

    const recordsPerPage = 20;
    final totalPages = maintenances.isEmpty ? 1 : (maintenances.length / recordsPerPage).ceil();

    for (var page = 0; page < totalPages; page++) {
      final startIdx = page * recordsPerPage;
      final endIdx = (startIdx + recordsPerPage > maintenances.length)
          ? maintenances.length
          : startIdx + recordsPerPage;
      final pageMaintenances = maintenances.sublist(startIdx, endIdx);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Maintenance Record (様式3)',
                      style: titleStyle,
                    ),
                    pw.Text('Page ${page + 1} / $totalPages', style: smallStyle),
                  ],
                ),
                pw.SizedBox(height: 4),

                if (aircraftName != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey700),
                    ),
                    child: pw.Text('Aircraft / 機体: $aircraftName', style: boldStyle),
                  ),
                pw.SizedBox(height: 8),

                // 整備記録テーブル
                pw.TableHelper.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(
                    color: PdfColors.grey600,
                    width: 0.5,
                  ),
                  headerStyle: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey700,
                  ),
                  cellStyle: smallStyle,
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerLeft,
                    5: pw.Alignment.centerLeft,
                    6: pw.Alignment.center,
                    7: pw.Alignment.center,
                    8: pw.Alignment.centerLeft,
                    9: pw.Alignment.centerLeft,
                  },
                  columnWidths: {
                    0: const pw.FixedColumnWidth(28),   // No.
                    1: const pw.FixedColumnWidth(62),   // Date
                    2: const pw.FixedColumnWidth(52),   // Type
                    3: const pw.FixedColumnWidth(72),   // Maintainer
                    4: const pw.FlexColumnWidth(2),     // Description
                    5: const pw.FixedColumnWidth(80),   // Parts
                    6: const pw.FixedColumnWidth(42),   // Result
                    7: const pw.FixedColumnWidth(62),   // Next Date
                    8: const pw.FixedColumnWidth(56),   // Supervisors
                    9: const pw.FlexColumnWidth(1),     // Notes
                  },
                  headers: [
                    'No.',
                    'Date\n日付',
                    'Type\n種別',
                    'Maintainer\n整備者',
                    'Description\n整備内容',
                    'Parts\n交換部品',
                    'Result\n結果',
                    'Next\n次回予定',
                    'Super.\n監督者',
                    'Notes\n備考',
                  ],
                  data: pageMaintenances.asMap().entries.map((entry) {
                    final idx = startIdx + entry.key + 1;
                    final m = entry.value;
                    final maintainer = maintainerNames?[m.maintainerId] ??
                        '#${m.maintainerId}';

                    return [
                      '$idx',
                      m.maintenanceDate,
                      m.maintenanceType,
                      maintainer,
                      m.description ?? '',
                      m.partsReplaced ?? '',
                      m.result ?? '',
                      m.nextMaintenanceDate ?? '',
                      m.supervisorNames.join(', '),
                      m.notes ?? '',
                    ];
                  }).toList(),
                ),

                pw.Spacer(),

                pw.Divider(color: PdfColors.grey400),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total maintenance records: ${maintenances.length}',
                      style: boldStyle,
                    ),
                    pw.Text('Generated: $outputDate', style: smallStyle),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// 月次飛行レポートPDF生成
  ///
  /// [flights] 対象期間の飛行記録
  /// [startDate] 期間開始日
  /// [endDate] 期間終了日
  /// [aircraftNames] 機体ID→名前のマップ
  /// [pilotNames] 操縦者ID→名前のマップ
  static Future<Uint8List> generateMonthlyReportPdf({
    required List<FlightRecordData> flights,
    required String startDate,
    required String endDate,
    Map<int, String>? aircraftNames,
    Map<int, String>? pilotNames,
  }) async {
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
    final headerStyle = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
    const normalStyle = pw.TextStyle(fontSize: 10);
    const smallStyle = pw.TextStyle(fontSize: 8);
    final boldStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
    final outputDate = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

    // ── 集計 ──
    final totalMinutes = _totalMinutes(flights);
    final totalH = totalMinutes ~/ 60;
    final totalM = totalMinutes % 60;

    // 機体別集計
    final byAircraft = <int, _AircraftSummary>{};
    for (final f in flights) {
      byAircraft.putIfAbsent(f.aircraftId, () => _AircraftSummary(
        name: aircraftNames?[f.aircraftId] ?? 'ID:${f.aircraftId}',
      ));
      byAircraft[f.aircraftId]!.count++;
      byAircraft[f.aircraftId]!.minutes += f.flightDuration ?? 0;
    }

    // 操縦者別集計
    final byPilot = <int, _PilotSummary>{};
    for (final f in flights) {
      byPilot.putIfAbsent(f.pilotId, () => _PilotSummary(
        name: pilotNames?[f.pilotId] ?? 'ID:${f.pilotId}',
      ));
      byPilot[f.pilotId]!.count++;
      byPilot[f.pilotId]!.minutes += f.flightDuration ?? 0;
    }

    // 目的別集計
    final byPurpose = <String, int>{};
    for (final f in flights) {
      final p = f.flightPurpose ?? '未設定';
      byPurpose[p] = (byPurpose[p] ?? 0) + 1;
    }

    // 飛行区域別集計
    final byArea = <String, int>{};
    for (final f in flights) {
      final a = f.flightArea ?? '未設定';
      byArea[a] = (byArea[a] ?? 0) + 1;
    }

    // ── ページ1: サマリー ──
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('Flight Monthly Report', style: titleStyle),
              pw.Text('飛行実績月次レポート', style: headerStyle),
              pw.SizedBox(height: 4),
              pw.Text('Period: $startDate ~ $endDate', style: normalStyle),
              pw.Divider(),
              pw.SizedBox(height: 12),

              // サマリーボックス
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey700),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  color: PdfColors.blueGrey50,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(children: [
                      pw.Text('Total Flights', style: boldStyle),
                      pw.Text('${flights.length}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.Column(children: [
                      pw.Text('Total Time', style: boldStyle),
                      pw.Text('${totalH}h ${totalM}m', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.Column(children: [
                      pw.Text('Aircraft Used', style: boldStyle),
                      pw.Text('${byAircraft.length}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.Column(children: [
                      pw.Text('Pilots', style: boldStyle),
                      pw.Text('${byPilot.length}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // 機体別テーブル
              pw.Text('Aircraft Summary / 機体別集計', style: headerStyle),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: normalStyle,
                headers: ['Aircraft / 機体', 'Flights / 回数', 'Time / 時間'],
                data: byAircraft.values.map((a) {
                  final h = a.minutes ~/ 60;
                  final m = a.minutes % 60;
                  return [a.name, '${a.count}', '${h}h ${m}m'];
                }).toList(),
              ),
              pw.SizedBox(height: 20),

              // 操縦者別テーブル
              pw.Text('Pilot Summary / 操縦者別集計', style: headerStyle),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: normalStyle,
                headers: ['Pilot / 操縦者', 'Flights / 回数', 'Time / 時間'],
                data: byPilot.values.map((p) {
                  final h = p.minutes ~/ 60;
                  final m = p.minutes % 60;
                  return [p.name, '${p.count}', '${h}h ${m}m'];
                }).toList(),
              ),
              pw.SizedBox(height: 20),

              // 目的別 + 区域別
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Purpose / 目的別', style: headerStyle),
                        pw.SizedBox(height: 8),
                        pw.TableHelper.fromTextArray(
                          context: context,
                          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                          cellStyle: normalStyle,
                          headers: ['Purpose', 'Count'],
                          data: byPurpose.entries.map((e) => [e.key, '${e.value}']).toList(),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Area / 区域別', style: headerStyle),
                        pw.SizedBox(height: 8),
                        pw.TableHelper.fromTextArray(
                          context: context,
                          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                          cellStyle: normalStyle,
                          headers: ['Area', 'Count'],
                          data: byArea.entries.map((e) => [e.key, '${e.value}']).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Text('Generated: $outputDate', style: smallStyle),
            ],
          );
        },
      ),
    );

    // ── ページ2+: 飛行記録一覧（様式1と同じ形式） ──
    if (flights.isNotEmpty) {
      const recordsPerPage = 25;
      final totalPages = (flights.length / recordsPerPage).ceil();

      for (var page = 0; page < totalPages; page++) {
        final startIdx = page * recordsPerPage;
        final endIdx = (startIdx + recordsPerPage > flights.length)
            ? flights.length
            : startIdx + recordsPerPage;
        final pageFlights = flights.sublist(startIdx, endIdx);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Flight Records Detail / 飛行記録詳細  ($startDate ~ $endDate)',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Page ${page + 1} / $totalPages', style: smallStyle),
                    ],
                  ),
                  pw.SizedBox(height: 8),

                  pw.TableHelper.fromTextArray(
                    context: context,
                    border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                    headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                    cellStyle: smallStyle,
                    columnWidths: {
                      0: const pw.FixedColumnWidth(28),
                      1: const pw.FixedColumnWidth(60),
                      2: const pw.FixedColumnWidth(36),
                      3: const pw.FixedColumnWidth(36),
                      4: const pw.FixedColumnWidth(30),
                      5: const pw.FixedColumnWidth(56),
                      6: const pw.FixedColumnWidth(100),
                      7: const pw.FixedColumnWidth(50),
                      8: const pw.FixedColumnWidth(60),
                      9: const pw.FixedColumnWidth(28),
                      10: const pw.FixedColumnWidth(30),
                      11: const pw.FixedColumnWidth(26),
                      12: const pw.FlexColumnWidth(),
                    },
                    headers: [
                      'No.', 'Date\n日付', 'T/O', 'LDG', 'Min',
                      'Pilot', 'Location', 'Purpose', 'Area',
                      'Alt', 'WX', 'Wind', 'Notes',
                    ],
                    data: pageFlights.asMap().entries.map((entry) {
                      final idx = startIdx + entry.key + 1;
                      final f = entry.value;
                      final pilot = pilotNames?[f.pilotId] ?? '#${f.pilotId}';
                      return [
                        '$idx',
                        f.flightDate,
                        f.takeoffTime ?? '-',
                        f.landingTime ?? '-',
                        f.flightDuration?.toString() ?? '-',
                        pilot,
                        f.takeoffLocation ?? '-',
                        f.flightPurpose ?? '-',
                        f.flightArea ?? '-',
                        f.maxAltitude ?? '-',
                        f.weather ?? '-',
                        f.windSpeed ?? '-',
                        f.notes ?? '',
                      ];
                    }).toList(),
                  ),

                  pw.Spacer(),
                  pw.Divider(color: PdfColors.grey400),
                  pw.Text('Generated: $outputDate', style: smallStyle),
                ],
              );
            },
          ),
        );
      }
    }

    return pdf.save();
  }

  /// 総飛行時間（分）を計算
  static int _totalMinutes(List<FlightRecordData> flights) {
    var total = 0;
    for (final f in flights) {
      total += f.flightDuration ?? 0;
    }
    return total;
  }

  /// 国交省提出用: 様式1〜3 + サマリーを一括PDF生成
  ///
  /// 期間指定で飛行記録・点検・整備をまとめた提出用PDFを生成
  static Future<Uint8List> generateBatchSubmissionPdf({
    required List<FlightRecordData> flights,
    required List<DailyInspectionData> inspections,
    required List<MaintenanceRecordData> maintenances,
    required String startDate,
    required String endDate,
    String? aircraftName,
    Map<String, String>? aircraftInfo,
    Map<int, String>? aircraftNames,
    Map<int, String>? pilotNames,
  }) async {
    final pdf = pw.Document();

    final headerStyle = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);
    const normalStyle = pw.TextStyle(fontSize: 9);
    const smallStyle = pw.TextStyle(fontSize: 8);
    final boldStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    final outputDate = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

    // ─── 表紙ページ ───
    final totalMinutes = _totalMinutes(flights);
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 80),
              pw.Text('無人航空機 飛行日誌', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('(様式1・様式2・様式3)', style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 60),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    _coverRow('対象期間', '$startDate ～ $endDate', boldStyle, normalStyle),
                    pw.SizedBox(height: 8),
                    _coverRow('飛行記録数', '${flights.length} 件', boldStyle, normalStyle),
                    pw.SizedBox(height: 8),
                    _coverRow('総飛行時間', '$hours時間$mins分', boldStyle, normalStyle),
                    pw.SizedBox(height: 8),
                    _coverRow('日常点検記録数', '${inspections.length} 件', boldStyle, normalStyle),
                    pw.SizedBox(height: 8),
                    _coverRow('整備記録数', '${maintenances.length} 件', boldStyle, normalStyle),
                    if (aircraftName != null) ...[
                      pw.SizedBox(height: 8),
                      _coverRow('機体', aircraftName, boldStyle, normalStyle),
                    ],
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Text('出力日: $outputDate', style: smallStyle),
            ],
          );
        },
      ),
    );

    // ─── 様式1: 飛行実績 ───
    if (flights.isNotEmpty) {
      const recordsPerPage = 20;
      final totalPages = (flights.length / recordsPerPage).ceil();

      for (var page = 0; page < totalPages; page++) {
        final startIdx = page * recordsPerPage;
        final endIdx = (startIdx + recordsPerPage > flights.length)
            ? flights.length
            : startIdx + recordsPerPage;
        final pageFlights = flights.sublist(startIdx, endIdx);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('様式1: 飛行実績記録 ($startDate～$endDate)', style: headerStyle),
                      pw.Text('${page + 1}/$totalPages', style: smallStyle),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    headerStyle: boldStyle,
                    cellStyle: smallStyle,
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    cellHeight: 22,
                    columnWidths: {
                      0: const pw.FixedColumnWidth(30),
                      1: const pw.FixedColumnWidth(70),
                      2: const pw.FixedColumnWidth(70),
                      3: const pw.FixedColumnWidth(65),
                      4: const pw.FixedColumnWidth(40),
                      5: const pw.FixedColumnWidth(40),
                      6: const pw.FixedColumnWidth(35),
                      7: const pw.FixedColumnWidth(80),
                      8: const pw.FixedColumnWidth(60),
                      9: const pw.FixedColumnWidth(80),
                      10: const pw.FixedColumnWidth(100),
                    },
                    headers: ['No', '飛行番号', '日付', '操縦者', '離陸', '着陸', '分', '場所', '目的', '機体', '備考'],
                    data: pageFlights.asMap().entries.map((entry) {
                      final i = startIdx + entry.key;
                      final f = entry.value;
                      final pilotName = pilotNames?[f.pilotId] ?? '操縦者${f.pilotId}';
                      final acName = aircraftNames?[f.aircraftId] ?? '機体${f.aircraftId}';
                      return [
                        '${i + 1}',
                        'FLT-${f.id.toString().padLeft(4, '0')}',
                        f.flightDate,
                        pilotName,
                        f.takeoffTime ?? '',
                        f.landingTime ?? '',
                        '${f.flightDuration ?? 0}',
                        f.takeoffLocation ?? '',
                        f.flightPurpose ?? '',
                        acName,
                        f.notes ?? '',
                      ];
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    // ─── 様式2: 日常点検記録 ───
    if (inspections.isNotEmpty) {
      const perPage = 25;
      final totalPages = (inspections.length / perPage).ceil();

      for (var page = 0; page < totalPages; page++) {
        final startIdx = page * perPage;
        final endIdx = (startIdx + perPage > inspections.length)
            ? inspections.length
            : startIdx + perPage;
        final pageItems = inspections.sublist(startIdx, endIdx);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('様式2: 日常点検記録 ($startDate～$endDate)', style: headerStyle),
                      pw.Text('${page + 1}/$totalPages', style: smallStyle),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    headerStyle: boldStyle,
                    cellStyle: smallStyle,
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    cellHeight: 22,
                    columnWidths: {
                      0: const pw.FixedColumnWidth(30),
                      1: const pw.FixedColumnWidth(75),
                      2: const pw.FixedColumnWidth(80),
                      3: const pw.FixedColumnWidth(70),
                      4: const pw.FixedColumnWidth(50),
                      5: const pw.FixedColumnWidth(200),
                      6: const pw.FixedColumnWidth(150),
                    },
                    headers: ['No', '点検日', '機体', '点検者', '結果', '点検項目', '備考'],
                    data: pageItems.asMap().entries.map((entry) {
                      final i = startIdx + entry.key;
                      final ins = entry.value;
                      final acName = aircraftNames?[ins.aircraftId] ?? '機体${ins.aircraftId}';
                      final inspector = pilotNames?[ins.inspectorId] ?? '点検者${ins.inspectorId}';
                      return [
                        '${i + 1}',
                        ins.inspectionDate,
                        acName,
                        inspector,
                        ins.overallResult,
                        _inspectionCheckedSummary(ins),
                        ins.notes ?? '',
                      ];
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    // ─── 様式3: 整備記録 ───
    if (maintenances.isNotEmpty) {
      const perPage = 20;
      final totalPages = (maintenances.length / perPage).ceil();

      for (var page = 0; page < totalPages; page++) {
        final startIdx = page * perPage;
        final endIdx = (startIdx + perPage > maintenances.length)
            ? maintenances.length
            : startIdx + perPage;
        final pageItems = maintenances.sublist(startIdx, endIdx);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('様式3: 整備記録 ($startDate～$endDate)', style: headerStyle),
                      pw.Text('${page + 1}/$totalPages', style: smallStyle),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    headerStyle: boldStyle,
                    cellStyle: smallStyle,
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    cellHeight: 22,
                    columnWidths: {
                      0: const pw.FixedColumnWidth(30),
                      1: const pw.FixedColumnWidth(75),
                      2: const pw.FixedColumnWidth(60),
                      3: const pw.FixedColumnWidth(70),
                      4: const pw.FixedColumnWidth(150),
                      5: const pw.FixedColumnWidth(70),
                      6: const pw.FixedColumnWidth(60),
                      7: const pw.FixedColumnWidth(120),
                    },
                    headers: ['No', '実施日', '種別', '実施者', '内容', '交換部品', '結果', '備考'],
                    data: pageItems.asMap().entries.map((entry) {
                      final i = startIdx + entry.key;
                      final m = entry.value;
                      return [
                        '${i + 1}',
                        m.maintenanceDate,
                        m.maintenanceType,
                        pilotNames?[m.maintainerId] ?? '実施者${m.maintainerId}',
                        m.description ?? '',
                        m.partsReplaced ?? '',
                        m.result ?? '',
                        m.notes ?? '',
                      ];
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    return pdf.save();
  }

  /// 日常点検のチェック項目を文字列サマリーに変換
  static String _inspectionCheckedSummary(DailyInspectionData ins) {
    final items = <String>[];
    if (ins.frameCheck) items.add('機体');
    if (ins.propellerCheck) items.add('プロペラ');
    if (ins.motorCheck) items.add('モーター');
    if (ins.batteryCheck) items.add('バッテリー');
    if (ins.controllerCheck) items.add('送信機');
    if (ins.gpsCheck) items.add('GPS');
    if (ins.cameraCheck) items.add('カメラ');
    if (ins.communicationCheck) items.add('通信');
    return items.isEmpty ? '-' : items.join(', ');
  }

  /// 表紙の1行ヘルパー
  static pw.Widget _coverRow(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Row(
      children: [
        pw.SizedBox(width: 140, child: pw.Text(label, style: labelStyle)),
        pw.Text(value, style: valueStyle),
      ],
    );
  }
}

/// 月次レポート用：機体別集計ヘルパー
class _AircraftSummary {
  final String name;
  int count = 0;
  int minutes = 0;
  _AircraftSummary({required this.name});
}

/// 月次レポート用：操縦者別集計ヘルパー
class _PilotSummary {
  final String name;
  int count = 0;
  int minutes = 0;
  _PilotSummary({required this.name});
}
