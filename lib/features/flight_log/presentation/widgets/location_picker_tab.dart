import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/database/location_history_storage.dart';

/// 位置情報ピッカーの結果
class LocationPickerResult {
  final String? address;
  final double? latitude;
  final double? longitude;

  LocationPickerResult({this.address, this.latitude, this.longitude});
}

/// 度分秒（DMS）形式に変換するユーティリティ
String _toDms(double decimal, {required bool isLat}) {
  final direction = isLat
      ? (decimal >= 0 ? 'N' : 'S')
      : (decimal >= 0 ? 'E' : 'W');
  final abs = decimal.abs();
  final deg = abs.floor();
  final minDecimal = (abs - deg) * 60;
  final min = minDecimal.floor();
  final sec = ((minDecimal - min) * 60).round();
  return '$deg:$min:$sec $direction';
}

/// 座標をDMS形式の文字列に変換
String formatDms(double lat, double lng) {
  return '${_toDms(lat, isLat: true)} ${_toDms(lng, isLat: false)}';
}

/// 離陸場所の位置情報ボタン拡張タブ
///
/// 6つのボタンで位置情報を操作:
/// 1. 現在位置取得 - GPSで現在地の座標→住所変換
/// 2. 地図から取得 - 地図画面でタップ選択（将来実装）
/// 3. 住所履歴から取得 - 過去に使用した住所から選択
/// 4. 位置情報クリア - 座標データのみクリア
/// 5. 位置情報&住所クリア - 座標・住所両方クリア
/// 6. 住所のみ取得 - テキスト入力で住所だけ設定
class LocationPickerTab extends StatefulWidget {
  final TextEditingController addressController;
  final ValueChanged<LocationPickerResult>? onLocationPicked;

  const LocationPickerTab({
    super.key,
    required this.addressController,
    this.onLocationPicked,
  });

  @override
  State<LocationPickerTab> createState() => _LocationPickerTabState();
}

class _LocationPickerTabState extends State<LocationPickerTab> {
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;
  final _historyStorage = LocationHistoryStorage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 現在の位置情報表示（DMS形式）
          if (_latitude != null && _longitude != null)
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            formatDms(_latitude!, _longitude!),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 住所コピーボタン
                    if (widget.addressController.text.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: widget.addressController.text,
                            ));
                            _showMsg('住所をコピーしました');
                          },
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('住所をコピー'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3D5A80),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: 8),

          // ボタングリッド（2列）
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: [
              // 1. 現在位置取得
              _ActionButton(
                icon: Icons.my_location,
                label: '現在位置取得',
                color: Colors.blue,
                onPressed: _isLoading ? null : _fetchCurrentLocation,
              ),
              // 2. 地図から取得
              _ActionButton(
                icon: Icons.map,
                label: '地図から取得',
                color: Colors.green,
                onPressed: _openMapPicker,
              ),
              // 3. 住所履歴から取得
              _ActionButton(
                icon: Icons.history,
                label: '住所履歴から取得',
                color: Colors.purple,
                onPressed: _showLocationHistory,
              ),
              // 4. 位置情報クリア
              _ActionButton(
                icon: Icons.location_off,
                label: '位置情報クリア',
                color: Colors.orange,
                onPressed: _clearLocation,
              ),
              // 5. 位置情報&住所クリア
              _ActionButton(
                icon: Icons.delete_sweep,
                label: '位置&住所クリア',
                color: Colors.red,
                onPressed: _clearAll,
              ),
              // 6. 住所のみ取得
              _ActionButton(
                icon: Icons.edit_location_alt,
                label: '住所のみ入力',
                color: Colors.teal,
                onPressed: _inputAddressOnly,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 1. 現在位置取得
  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMsg('位置情報サービスが無効です');
        setState(() => _isLoading = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMsg('位置情報の権限が拒否されました');
          setState(() => _isLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showMsg('位置情報の権限を設定から変更してください');
        setState(() => _isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 逆ジオコーディング
      String addressText;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
            if (p.locality?.isNotEmpty == true) p.locality!,
            if (p.subLocality?.isNotEmpty == true) p.subLocality!,
            if (p.thoroughfare?.isNotEmpty == true) p.thoroughfare!,
            if (p.subThoroughfare?.isNotEmpty == true) p.subThoroughfare!,
          ];
          if (parts.isEmpty && p.name?.isNotEmpty == true) parts.add(p.name!);
          addressText = parts.isNotEmpty ? parts.join('')
              : '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        } else {
          addressText = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        }
      } catch (_) {
        addressText = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        widget.addressController.text = addressText;
        _isLoading = false;
      });

      // 履歴に記録
      await _historyStorage.init();
      await _historyStorage.recordLocation(
        address: addressText,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      widget.onLocationPicked?.call(LocationPickerResult(
        address: addressText,
        latitude: position.latitude,
        longitude: position.longitude,
      ));
    } catch (e) {
      _showMsg('位置情報取得に失敗: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 2. 地図から取得（今後Google Maps連携で実装）
  void _openMapPicker() {
    _showMsg('地図選択機能は今後のアップデートで対応予定です');
  }

  /// 3. 住所履歴から選択
  Future<void> _showLocationHistory() async {
    await _historyStorage.init();
    final histories = await _historyStorage.getAll();

    if (!mounted) return;

    if (histories.isEmpty) {
      _showMsg('住所履歴がありません');
      return;
    }

    final selected = await showModalBottomSheet<LocationHistoryData>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.purple),
                  const SizedBox(width: 8),
                  const Text(
                    '住所履歴',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text('${histories.length}件',
                    style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: histories.length,
                itemBuilder: (_, index) {
                  final h = histories[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple[50],
                      child: Text('${h.usedCount}', style: const TextStyle(fontSize: 12)),
                    ),
                    title: Text(h.address, style: const TextStyle(fontSize: 14)),
                    subtitle: h.latitude != null
                        ? Text(
                            '${h.latitude!.toStringAsFixed(4)}, ${h.longitude!.toStringAsFixed(4)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          )
                        : null,
                    onTap: () => Navigator.pop(ctx, h),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        widget.addressController.text = selected.address;
        _latitude = selected.latitude;
        _longitude = selected.longitude;
      });

      // 使用回数を増加
      await _historyStorage.recordLocation(
        address: selected.address,
        latitude: selected.latitude,
        longitude: selected.longitude,
      );

      widget.onLocationPicked?.call(LocationPickerResult(
        address: selected.address,
        latitude: selected.latitude,
        longitude: selected.longitude,
      ));
    }
  }

  /// 4. 位置情報クリア（座標のみ。住所テキストは保持）
  void _clearLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
    });
    _showMsg('位置情報をクリアしました（住所テキストは保持）');
  }

  /// 5. 位置情報&住所クリア
  void _clearAll() {
    setState(() {
      _latitude = null;
      _longitude = null;
      widget.addressController.clear();
    });
    widget.onLocationPicked?.call(LocationPickerResult());
    _showMsg('位置情報と住所をクリアしました');
  }

  /// 6. 住所のみ手動入力
  Future<void> _inputAddressOnly() async {
    final controller = TextEditingController(
      text: widget.addressController.text,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('住所を入力'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '例: 東京都千代田区1-1',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('設定'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null && mounted) {
      setState(() {
        widget.addressController.text = result;
        // 座標なしで住所だけ設定
        _latitude = null;
        _longitude = null;
      });

      // 履歴に記録
      if (result.isNotEmpty) {
        await _historyStorage.init();
        await _historyStorage.recordLocation(address: result);
      }

      widget.onLocationPicked?.call(LocationPickerResult(address: result));
    }
  }

  void _showMsg(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }
}

/// アクションボタン
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
