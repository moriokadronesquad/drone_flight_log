import 'dart:typed_data';

/// 非Web環境用のスタブ実装
/// モバイル（iOS/Android）では将来的にshare_plusなどで対応可能
void downloadCsvFile(String csvContent, String fileName) {
  // モバイル環境では未実装
  throw UnsupportedError('この機能はWeb環境でのみ利用可能です');
}

/// 非Web環境用のバイナリファイルダウンロードスタブ
void downloadBinaryFile(Uint8List bytes, String fileName) {
  throw UnsupportedError('この機能はWeb環境でのみ利用可能です');
}
