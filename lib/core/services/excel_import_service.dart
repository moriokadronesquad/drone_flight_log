import 'dart:typed_data';
import 'package:excel/excel.dart';

/// Excelインポートサービス
///
/// .xlsxファイルから飛行記録をインポートする
/// ドローンログのエクスポート形式に準拠、または汎用的なカラム名にも対応
class ExcelImportService {
  /// Excelファイルから飛行記録を読み込む
  ///
  /// 返値: インポートされた飛行記録のリストとエラーメッセージ
  static ExcelImportResult importFlights(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final errors = <String>[];
      final flights = <Map<String, String>>[];

      // 飛行記録シートを探す
      Sheet? targetSheet;
      for (final name in excel.tables.keys) {
        if (name.contains('飛行記録') || name.contains('Flight') || name == 'Sheet1') {
          targetSheet = excel.tables[name];
          break;
        }
      }

      if (targetSheet == null && excel.tables.isNotEmpty) {
        targetSheet = excel.tables.values.first;
      }

      if (targetSheet == null) {
        return ExcelImportResult(
          flights: [],
          errors: ['Excelファイルにシートが見つかりません'],
          totalRows: 0,
        );
      }

      // ヘッダー行を検出（カラム名マッピング）
      final rows = targetSheet.rows;
      if (rows.isEmpty) {
        return ExcelImportResult(flights: [], errors: ['データが空です'], totalRows: 0);
      }

      // ヘッダー行のカラムインデックスをマッピング
      final headerRow = rows.first;
      final columnMap = <String, int>{};

      for (var col = 0; col < headerRow.length; col++) {
        final cell = headerRow[col];
        if (cell == null) continue;
        final value = cell.value?.toString().trim() ?? '';
        if (value.isEmpty) continue;

        // 日本語/英語のカラム名に対応
        final normalized = _normalizeColumnName(value);
        if (normalized != null) {
          columnMap[normalized] = col;
        }
      }

      if (!columnMap.containsKey('date')) {
        return ExcelImportResult(
          flights: [],
          errors: ['日付列が見つかりません。ヘッダー行に「日付」「飛行日」「Date」のいずれかが必要です'],
          totalRows: 0,
        );
      }

      // データ行を読み取り
      for (var row = 1; row < rows.length; row++) {
        try {
          final cells = rows[row];
          final record = <String, String>{};

          String getCellValue(String key) {
            final colIdx = columnMap[key];
            if (colIdx == null || colIdx >= cells.length) return '';
            final cell = cells[colIdx];
            if (cell == null) return '';
            return cell.value?.toString().trim() ?? '';
          }

          final date = getCellValue('date');
          if (date.isEmpty) continue; // 日付なしの行はスキップ

          record['flightDate'] = _normalizeDate(date);
          record['flightNumber'] = getCellValue('flightNumber');
          record['takeoffTime'] = getCellValue('takeoffTime');
          record['landingTime'] = getCellValue('landingTime');
          record['flightDuration'] = getCellValue('duration');
          record['flightLocation'] = getCellValue('location');
          record['flightPurpose'] = getCellValue('purpose');
          record['notes'] = getCellValue('notes');
          record['aircraftName'] = getCellValue('aircraft');
          record['pilotName'] = getCellValue('pilot');

          flights.add(record);
        } catch (e) {
          errors.add('行${row + 1}: 読み取りエラー ($e)');
        }
      }

      return ExcelImportResult(
        flights: flights,
        errors: errors,
        totalRows: rows.length - 1,
      );
    } catch (e) {
      return ExcelImportResult(
        flights: [],
        errors: ['Excelファイルの解析に失敗しました: $e'],
        totalRows: 0,
      );
    }
  }

  /// カラム名を正規化してマッピングキーに変換
  static String? _normalizeColumnName(String name) {
    final lower = name.toLowerCase();

    // 日付
    if (lower.contains('日付') || lower.contains('飛行日') || lower == 'date') {
      return 'date';
    }
    // 飛行番号
    if (lower.contains('飛行番号') || lower.contains('flight number') || lower.contains('flt')) {
      return 'flightNumber';
    }
    // 離陸時刻
    if (lower.contains('離陸') || lower.contains('takeoff') || lower.contains('出発')) {
      return 'takeoffTime';
    }
    // 着陸時刻
    if (lower.contains('着陸') || lower.contains('landing') || lower.contains('到着')) {
      return 'landingTime';
    }
    // 飛行時間
    if (lower.contains('飛行時間') || lower.contains('duration') || lower.contains('時間')) {
      return 'duration';
    }
    // 場所
    if (lower.contains('場所') || lower.contains('location') || lower.contains('飛行場所') || lower.contains('エリア')) {
      return 'location';
    }
    // 目的
    if (lower.contains('目的') || lower.contains('purpose')) {
      return 'purpose';
    }
    // 備考
    if (lower.contains('備考') || lower.contains('notes') || lower.contains('メモ')) {
      return 'notes';
    }
    // 機体
    if (lower.contains('機体') || lower.contains('aircraft') || lower.contains('登録番号')) {
      return 'aircraft';
    }
    // 操縦者
    if (lower.contains('操縦者') || lower.contains('pilot') || lower.contains('パイロット')) {
      return 'pilot';
    }

    return null;
  }

  /// 日付文字列を yyyy-MM-dd 形式に正規化
  static String _normalizeDate(String date) {
    // yyyy/MM/dd → yyyy-MM-dd
    final normalized = date.replaceAll('/', '-');

    // すでに正しい形式ならそのまま
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
      return normalized;
    }

    // yyyy-M-d 形式をゼロパディング
    final parts = normalized.split('-');
    if (parts.length == 3) {
      final year = parts[0].padLeft(4, '0');
      final month = parts[1].padLeft(2, '0');
      final day = parts[2].padLeft(2, '0');
      return '$year-$month-$day';
    }

    return date; // 変換不能ならそのまま返す
  }
}

/// Excelインポート結果
class ExcelImportResult {
  final List<Map<String, String>> flights;
  final List<String> errors;
  final int totalRows;

  ExcelImportResult({
    required this.flights,
    required this.errors,
    required this.totalRows,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get successCount => flights.length;
}
