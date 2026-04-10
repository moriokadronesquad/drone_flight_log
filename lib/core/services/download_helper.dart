/// プラットフォーム別ダウンロードヘルパー
/// Web環境では dart:html を使用、それ以外ではスタブを使用
library;
export 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';
