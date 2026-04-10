// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

/// Web環境用のCSVダウンロード実装
/// ブラウザのダウンロード機能を使ってCSVファイルを保存
void downloadCsvFile(String csvContent, String fileName) {
  // BOM付きUTF-8でエンコード（Excelで日本語が文字化けしないように）
  final bom = [0xEF, 0xBB, 0xBF];
  final csvBytes = utf8.encode(csvContent);
  final allBytes = Uint8List.fromList([...bom, ...csvBytes]);

  final blob = html.Blob([allBytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  html.Url.revokeObjectUrl(url);
}

/// Web環境用のバイナリファイルダウンロード実装
void downloadBinaryFile(Uint8List bytes, String fileName) {
  final mimeType = fileName.endsWith('.xlsx')
      ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      : 'application/octet-stream';

  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  html.Url.revokeObjectUrl(url);
}
