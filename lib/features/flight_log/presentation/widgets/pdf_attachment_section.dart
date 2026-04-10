import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// PDF添付データ
class PdfAttachment {
  final String name;
  final Uint8List bytes;
  final DateTime addedAt;

  PdfAttachment({
    required this.name,
    required this.bytes,
    required this.addedAt,
  });

  /// Base64文字列に変換（保存用）
  String toBase64() => base64Encode(bytes);

  /// Base64文字列から復元
  factory PdfAttachment.fromBase64(String name, String data) {
    return PdfAttachment(
      name: name,
      bytes: base64Decode(data),
      addedAt: DateTime.now(),
    );
  }

  /// ファイルサイズをフォーマット
  String get formattedSize {
    final kb = bytes.length / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

/// PDF添付セクションウィジェット
///
/// 許可承認セクションで飛行許可書PDFをインポート・表示する。
/// - file_pickerでPDFファイルを選択
/// - 添付済みPDF一覧表示（ファイル名+サイズ）
/// - 削除機能
class PdfAttachmentSection extends StatefulWidget {
  final List<PdfAttachment> initialPdfs;
  final ValueChanged<List<PdfAttachment>>? onChanged;

  const PdfAttachmentSection({
    super.key,
    this.initialPdfs = const [],
    this.onChanged,
  });

  @override
  State<PdfAttachmentSection> createState() => _PdfAttachmentSectionState();
}

class _PdfAttachmentSectionState extends State<PdfAttachmentSection> {
  late List<PdfAttachment> _pdfs;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pdfs = List.from(widget.initialPdfs);
  }

  /// PDFファイルを選択してインポート
  Future<void> _pickPdf() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true, // バイトデータを取得
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.bytes != null) {
            setState(() {
              _pdfs.add(PdfAttachment(
                name: file.name,
                bytes: file.bytes!,
                addedAt: DateTime.now(),
              ));
            });
          }
        }
        widget.onChanged?.call(_pdfs);
      }
    } catch (e) {
      _showMsg('PDFの読み込みに失敗しました: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// PDFを削除
  void _removePdf(int index) {
    setState(() {
      _pdfs.removeAt(index);
    });
    widget.onChanged?.call(_pdfs);
  }

  void _showMsg(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PDFインポートボタン
        Center(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _pickPdf,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf, size: 16),
            label: Text(_isLoading ? '読み込み中...' : 'PDF読込'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB03A2E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // 添付PDF一覧
        if (_pdfs.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...List.generate(_pdfs.length, (index) {
            final pdf = _pdfs[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
                title: Text(
                  pdf.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  pdf.formattedSize,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _removePdf(index),
                  tooltip: '削除',
                ),
                dense: true,
              ),
            );
          }),
          Text(
            '${_pdfs.length}件のPDFファイル',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
