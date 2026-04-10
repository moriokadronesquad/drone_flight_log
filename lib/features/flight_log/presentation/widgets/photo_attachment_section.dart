import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 写真添付データ
class PhotoAttachment {
  final String name;
  final Uint8List bytes;
  final DateTime addedAt;

  PhotoAttachment({
    required this.name,
    required this.bytes,
    required this.addedAt,
  });

  /// Base64文字列に変換（保存用）
  String toBase64() => base64Encode(bytes);

  /// Base64文字列から復元
  factory PhotoAttachment.fromBase64(String name, String data) {
    return PhotoAttachment(
      name: name,
      bytes: base64Decode(data),
      addedAt: DateTime.now(),
    );
  }
}

/// 写真添付セクションウィジェット
///
/// 参考アプリの「写真」「撮影」ボタンに対応。
/// - 撮影: カメラで写真を撮る（モバイルのみ）
/// - 写真: ギャラリーから選択
/// - Web対応: ファイル選択ダイアログを使用
class PhotoAttachmentSection extends StatefulWidget {
  final List<PhotoAttachment> initialPhotos;
  final ValueChanged<List<PhotoAttachment>>? onChanged;

  const PhotoAttachmentSection({
    super.key,
    this.initialPhotos = const [],
    this.onChanged,
  });

  @override
  State<PhotoAttachmentSection> createState() => _PhotoAttachmentSectionState();
}

class _PhotoAttachmentSectionState extends State<PhotoAttachmentSection> {
  final _picker = ImagePicker();
  late List<PhotoAttachment> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.initialPhotos);
  }

  /// ギャラリーから写真を選択
  Future<void> _pickFromGallery() async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      for (final image in images) {
        final bytes = await image.readAsBytes();
        setState(() {
          _photos.add(PhotoAttachment(
            name: image.name,
            bytes: bytes,
            addedAt: DateTime.now(),
          ));
        });
      }
      widget.onChanged?.call(_photos);
    } catch (e) {
      _showMsg('写真の選択に失敗しました: $e');
    }
  }

  /// カメラで撮影
  Future<void> _takePhoto() async {
    // Web環境ではカメラ撮影をギャラリー選択にフォールバック
    if (kIsWeb) {
      await _pickFromGallery();
      return;
    }

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _photos.add(PhotoAttachment(
            name: image.name,
            bytes: bytes,
            addedAt: DateTime.now(),
          ));
        });
        widget.onChanged?.call(_photos);
      }
    } catch (e) {
      _showMsg('撮影に失敗しました: $e');
    }
  }

  /// 写真を削除
  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
    widget.onChanged?.call(_photos);
  }

  /// 写真をフルスクリーンで表示
  void _viewPhoto(PhotoAttachment photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(photo.name, style: const TextStyle(fontSize: 14)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(
                  photo.bytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        // ボタン行（写真 + 撮影）
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library, size: 16),
              label: const Text('写真'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5A80),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('撮影'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5A80),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        // 写真プレビュー
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      // サムネイル
                      GestureDetector(
                        onTap: () => _viewPhoto(photo),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            photo.bytes,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // 削除ボタン
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${_photos.length}枚の写真',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}
