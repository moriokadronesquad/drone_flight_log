import 'package:flutter/material.dart';

/// 飛行メモデータ（フォーム内で使用）
class FlightMemoData {
  String? ownerConsent;     // 所有者や管理者の承諾・許可申請関連
  String? windSpeed;        // 風速 m/s
  String? temperature;      // 気温 ℃
  String? weather;          // 天候
  int? batteryBefore;       // バッテリー飛行前 %
  int? batteryAfter;        // バッテリー飛行後 %
  String? batteryNumber;    // バッテリーNo
  String? flightDistance;   // 飛行距離 m
  String? notes;            // その他飛行メモ

  FlightMemoData({
    this.ownerConsent,
    this.windSpeed,
    this.temperature,
    this.weather,
    this.batteryBefore,
    this.batteryAfter,
    this.batteryNumber,
    this.flightDistance,
    this.notes,
  });
}

/// 飛行メモセクションウィジェット
///
/// 参考アプリの「飛行メモ」セクションに対応。
/// 風速、気温、天候に加え、バッテリー残量、飛行距離、
/// 所有者承諾情報などを記録できる。
class FlightMemoSection extends StatefulWidget {
  final FlightMemoData initialData;
  final ValueChanged<FlightMemoData>? onChanged;

  const FlightMemoSection({
    super.key,
    required this.initialData,
    this.onChanged,
  });

  @override
  State<FlightMemoSection> createState() => _FlightMemoSectionState();
}

class _FlightMemoSectionState extends State<FlightMemoSection> {
  late TextEditingController _ownerConsentController;
  late TextEditingController _windSpeedController;
  late TextEditingController _temperatureController;
  late TextEditingController _weatherController;
  late TextEditingController _batteryBeforeController;
  late TextEditingController _batteryAfterController;
  late TextEditingController _batteryNumberController;
  late TextEditingController _flightDistanceController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _ownerConsentController = TextEditingController(text: d.ownerConsent);
    _windSpeedController = TextEditingController(text: d.windSpeed);
    _temperatureController = TextEditingController(text: d.temperature);
    _weatherController = TextEditingController(text: d.weather);
    _batteryBeforeController = TextEditingController(
      text: d.batteryBefore?.toString(),
    );
    _batteryAfterController = TextEditingController(
      text: d.batteryAfter?.toString(),
    );
    _batteryNumberController = TextEditingController(text: d.batteryNumber);
    _flightDistanceController = TextEditingController(text: d.flightDistance);
    _notesController = TextEditingController(text: d.notes);
  }

  @override
  void dispose() {
    _ownerConsentController.dispose();
    _windSpeedController.dispose();
    _temperatureController.dispose();
    _weatherController.dispose();
    _batteryBeforeController.dispose();
    _batteryAfterController.dispose();
    _batteryNumberController.dispose();
    _flightDistanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged?.call(FlightMemoData(
      ownerConsent: _ownerConsentController.text.isNotEmpty
          ? _ownerConsentController.text : null,
      windSpeed: _windSpeedController.text.isNotEmpty
          ? _windSpeedController.text : null,
      temperature: _temperatureController.text.isNotEmpty
          ? _temperatureController.text : null,
      weather: _weatherController.text.isNotEmpty
          ? _weatherController.text : null,
      batteryBefore: int.tryParse(_batteryBeforeController.text),
      batteryAfter: int.tryParse(_batteryAfterController.text),
      batteryNumber: _batteryNumberController.text.isNotEmpty
          ? _batteryNumberController.text : null,
      flightDistance: _flightDistanceController.text.isNotEmpty
          ? _flightDistanceController.text : null,
      notes: _notesController.text.isNotEmpty
          ? _notesController.text : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 所有者や管理者の承諾・許可申請関連
        Card(
          elevation: 0,
          color: Colors.grey[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '所有者や管理者の承諾・許可申請関連',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ownerConsentController,
                  decoration: const InputDecoration(
                    hintText: '申請内容や連絡先など\n例)○○土木事務所 担当○○氏',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (_) => _notifyChange(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 風速・気温・天候
        Card(
          elevation: 0,
          color: Colors.grey[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // 風速
                Row(
                  children: [
                    const SizedBox(width: 80, child: Text('風速', style: TextStyle(fontSize: 13))),
                    Expanded(
                      child: TextField(
                        controller: _windSpeedController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => _notifyChange(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('m/s', style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                // 気温
                Row(
                  children: [
                    const SizedBox(width: 80, child: Text('気温', style: TextStyle(fontSize: 13))),
                    Expanded(
                      child: TextField(
                        controller: _temperatureController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => _notifyChange(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('℃', style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                // 天候
                Row(
                  children: [
                    const SizedBox(width: 80, child: Text('天候', style: TextStyle(fontSize: 13))),
                    Expanded(
                      child: TextField(
                        controller: _weatherController,
                        decoration: const InputDecoration(
                          hintText: '例)晴れ,くもり',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => _notifyChange(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // バッテリー情報
        Card(
          elevation: 0,
          color: Colors.grey[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // バッテリー飛行前
                Row(
                  children: [
                    const SizedBox(
                      width: 120,
                      child: Text('バッテリー飛行前', style: TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _batteryBeforeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => _notifyChange(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                // バッテリー飛行後
                Row(
                  children: [
                    const SizedBox(
                      width: 120,
                      child: Text('バッテリー飛行後', style: TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _batteryAfterController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => _notifyChange(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                // バッテリーNo
                Row(
                  children: [
                    const SizedBox(
                      width: 120,
                      child: Text('バッテリーNoなど', style: TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _batteryNumberController,
                        decoration: const InputDecoration(
                          hintText: '例)No1',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => _notifyChange(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 飛行距離
                Row(
                  children: [
                    const SizedBox(
                      width: 120,
                      child: Text('飛行距離', style: TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _flightDistanceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (_) => _notifyChange(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('m', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // その他飛行メモ
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'その他飛行メモ',
            hintText: '直接入力',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (_) => _notifyChange(),
        ),
      ],
    );
  }
}
