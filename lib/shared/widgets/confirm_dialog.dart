import 'package:flutter/material.dart';

/// 確認ダイアログウィジェット
/// 削除などの取り消せない操作の確認に使用
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmButtonColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = '確認',
    this.cancelText = 'キャンセル',
    required this.onConfirm,
    this.onCancel,
    this.confirmButtonColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancel?.call();
          },
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmButtonColor ?? Colors.red,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
