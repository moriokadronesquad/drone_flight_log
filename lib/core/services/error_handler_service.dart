import 'package:flutter/material.dart';

/// エラーの種類を表す列挙型
enum AppErrorType {
  /// ストレージ読み書きエラー
  storage,

  /// ネットワーク接続エラー
  network,

  /// バリデーションエラー
  validation,

  /// データ変換エラー
  parse,

  /// PDF/Excel生成エラー
  export_,

  /// 不明なエラー
  unknown,
}

/// アプリ共通エラークラス
class AppError {
  final AppErrorType type;
  final String message;
  final String? detail;

  const AppError({
    required this.type,
    required this.message,
    this.detail,
  });

  /// エラー種別ごとのアイコン
  IconData get icon {
    switch (type) {
      case AppErrorType.storage:
        return Icons.storage;
      case AppErrorType.network:
        return Icons.wifi_off;
      case AppErrorType.validation:
        return Icons.warning_amber;
      case AppErrorType.parse:
        return Icons.code_off;
      case AppErrorType.export_:
        return Icons.file_download_off;
      case AppErrorType.unknown:
        return Icons.error_outline;
    }
  }

  /// エラー種別ごとの色
  Color get color {
    switch (type) {
      case AppErrorType.storage:
        return Colors.orange;
      case AppErrorType.network:
        return Colors.blue;
      case AppErrorType.validation:
        return Colors.amber;
      case AppErrorType.parse:
        return Colors.purple;
      case AppErrorType.export_:
        return Colors.red;
      case AppErrorType.unknown:
        return Colors.red;
    }
  }
}

/// 統一エラーハンドリングサービス
/// try-catchのラッパーと、ユーザーへのフィードバック表示を統一する
class ErrorHandlerService {
  /// 非同期処理をラップし、エラー発生時にフォールバック値を返す
  /// デバッグログも自動出力する
  static Future<T> guardAsync<T>({
    required Future<T> Function() action,
    required T fallback,
    AppErrorType errorType = AppErrorType.unknown,
    String? context,
  }) async {
    try {
      return await action();
    } catch (e, stackTrace) {
      final label = context ?? 'guardAsync';
      debugPrint('[$label] エラー発生: $e');
      debugPrint('$stackTrace');
      return fallback;
    }
  }

  /// 非同期処理を実行し、成功/失敗をAppError?で返す
  /// 成功時はnull、失敗時はAppErrorを返す
  static Future<AppError?> tryAsync({
    required Future<void> Function() action,
    AppErrorType errorType = AppErrorType.unknown,
    String? context,
    String? userMessage,
  }) async {
    try {
      await action();
      return null;
    } catch (e, stackTrace) {
      final label = context ?? 'tryAsync';
      debugPrint('[$label] エラー発生: $e');
      debugPrint('$stackTrace');
      return AppError(
        type: errorType,
        message: userMessage ?? _defaultMessage(errorType),
        detail: e.toString(),
      );
    }
  }

  /// エラーメッセージをSnackBarで表示する
  static void showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// 成功メッセージをSnackBarで表示する
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 警告メッセージをSnackBarで表示する
  static void showWarningSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// AppErrorを表示用ダイアログで表示する
  static void showErrorDialog(BuildContext context, AppError error) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(error.icon, color: error.color),
            const SizedBox(width: 8),
            const Expanded(child: Text('エラーが発生しました')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message),
            if (error.detail != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  error.detail!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// エラー種類ごとのデフォルトメッセージ
  static String _defaultMessage(AppErrorType type) {
    switch (type) {
      case AppErrorType.storage:
        return 'データの保存・読み込みに失敗しました。アプリを再起動してください。';
      case AppErrorType.network:
        return 'ネットワーク接続に問題があります。接続を確認してください。';
      case AppErrorType.validation:
        return '入力内容に問題があります。内容を確認してください。';
      case AppErrorType.parse:
        return 'データの変換に失敗しました。ファイル形式を確認してください。';
      case AppErrorType.export_:
        return 'ファイルの生成に失敗しました。もう一度お試しください。';
      case AppErrorType.unknown:
        return '予期しないエラーが発生しました。もう一度お試しください。';
    }
  }
}
