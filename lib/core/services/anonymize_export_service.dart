import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// データ匿名化エクスポートサービス
/// 個人情報（操縦者名、連絡先等）をマスクした状態で
/// データをJSON出力する。デモ用やデータ分析向けに使用
class AnonymizeExportService {
  /// 匿名化済みの全データをJSON文字列で返す
  static Future<String> exportAnonymized() async {
    final prefs = await SharedPreferences.getInstance();

    // 操縦者データの匿名化
    final pilotsRaw = prefs.getString('drone_app_pilots');
    final anonymizedPilots = <Map<String, dynamic>>[];
    final pilotNameMap = <int, String>{}; // 元ID → 匿名名マップ
    if (pilotsRaw != null) {
      final pilots = jsonDecode(pilotsRaw) as List;
      for (var i = 0; i < pilots.length; i++) {
        final p = Map<String, dynamic>.from(pilots[i] as Map);
        final id = p['id'] as int? ?? i;
        final anonName = '操縦者${(i + 1).toString().padLeft(2, '0')}';
        pilotNameMap[id] = anonName;

        p['name'] = anonName;
        // メールや電話番号をマスク
        if (p.containsKey('email')) p['email'] = '***@***.***';
        if (p.containsKey('phone')) p['phone'] = '***-****-****';
        if (p.containsKey('address')) p['address'] = '***';
        if (p.containsKey('licenseNumber')) {
          p['licenseNumber'] = 'LIC-XXXX-${(i + 1).toString().padLeft(3, '0')}';
        }
        if (p.containsKey('notes')) p['notes'] = '';
        anonymizedPilots.add(p);
      }
    }

    // 機体データの匿名化（登録番号をマスク）
    final aircraftsRaw = prefs.getString('drone_app_aircrafts');
    final anonymizedAircrafts = <Map<String, dynamic>>[];
    if (aircraftsRaw != null) {
      final aircrafts = jsonDecode(aircraftsRaw) as List;
      for (var i = 0; i < aircrafts.length; i++) {
        final a = Map<String, dynamic>.from(aircrafts[i] as Map);
        a['registrationNumber'] = 'JA-XXXX-${(i + 1).toString().padLeft(3, '0')}';
        if (a.containsKey('serialNumber')) {
          a['serialNumber'] = 'SN-XXXX-${(i + 1).toString().padLeft(3, '0')}';
        }
        if (a.containsKey('notes')) a['notes'] = '';
        anonymizedAircrafts.add(a);
      }
    }

    // 飛行記録の匿名化（場所名を汎用化）
    final flightsRaw = prefs.getString('drone_app_flights');
    final anonymizedFlights = <Map<String, dynamic>>[];
    if (flightsRaw != null) {
      final flights = jsonDecode(flightsRaw) as List;
      for (var i = 0; i < flights.length; i++) {
        final f = Map<String, dynamic>.from(flights[i] as Map);
        if (f.containsKey('takeoffLocation')) {
          f['takeoffLocation'] = '飛行場所${(i + 1).toString().padLeft(3, '0')}';
        }
        if (f.containsKey('landingLocation')) {
          f['landingLocation'] = '着陸場所${(i + 1).toString().padLeft(3, '0')}';
        }
        if (f.containsKey('notes')) f['notes'] = '';
        if (f.containsKey('supervisorNotes')) f['supervisorNotes'] = '';
        anonymizedFlights.add(f);
      }
    }

    // 点検記録の匿名化
    final inspectionsRaw = prefs.getString('drone_app_inspections');
    final anonymizedInspections = <Map<String, dynamic>>[];
    if (inspectionsRaw != null) {
      final inspections = jsonDecode(inspectionsRaw) as List;
      for (final ins in inspections) {
        final i = Map<String, dynamic>.from(ins as Map);
        if (i.containsKey('notes')) i['notes'] = '';
        anonymizedInspections.add(i);
      }
    }

    // 整備記録の匿名化
    final maintenancesRaw = prefs.getString('drone_app_maintenances');
    final anonymizedMaintenances = <Map<String, dynamic>>[];
    if (maintenancesRaw != null) {
      final maintenances = jsonDecode(maintenancesRaw) as List;
      for (final mnt in maintenances) {
        final m = Map<String, dynamic>.from(mnt as Map);
        if (m.containsKey('notes')) m['notes'] = '';
        anonymizedMaintenances.add(m);
      }
    }

    // 匿名化データを構築
    final anonymized = <String, dynamic>{
      'appName': 'ドローン飛行日誌（匿名化済み）',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'notice': 'このデータは個人情報を匿名化して出力されています',
      'drone_app_pilots': anonymizedPilots,
      'drone_app_aircrafts': anonymizedAircrafts,
      'drone_app_flights': anonymizedFlights,
      'drone_app_inspections': anonymizedInspections,
      'drone_app_maintenances': anonymizedMaintenances,
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(anonymized);
  }
}
