import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../features/aircraft/domain/entities/aircraft.dart';

/// QRコード共有サービス
/// 機体情報をQRコードとして表示し、他端末で読み取り可能にする
class QrShareService {
  /// 機体情報をQRコード用JSON文字列に変換
  static String aircraftToQrData(Aircraft aircraft) {
    final data = {
      'type': 'drone_note_aircraft',
      'version': 1,
      'registration': aircraft.registrationNumber,
      'aircraftType': aircraft.aircraftType,
      'model': aircraft.modelName,
      'manufacturer': aircraft.manufacturer,
      'serialNumber': aircraft.serialNumber,
    };
    return jsonEncode(data);
  }

  /// 機体QRコードダイアログを表示
  static void showAircraftQrDialog(BuildContext context, Aircraft aircraft) {
    final qrData = aircraftToQrData(aircraft);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_2, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '機体情報QRコード',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 機体名
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blueGrey.shade700 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flight, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            aircraft.registrationNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (aircraft.modelName != null)
                            Text(
                              aircraft.modelName!,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // QRコード
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  gapless: true,
                  errorStateBuilder: (ctx, err) {
                    return const Center(
                      child: Text('QRコードの生成に失敗しました'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '他端末のQRリーダーで読み取ると\n機体情報を取得できます',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
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
}
