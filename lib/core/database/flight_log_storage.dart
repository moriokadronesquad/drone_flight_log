import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 飛行実績データクラス（様式1）
class FlightRecordData {
  final int id;
  final int aircraftId;
  final int pilotId;
  final String flightDate;
  final String? takeoffTime;
  final String? landingTime;
  final int? flightDuration;
  final String? takeoffLocation;
  final String? landingLocation;
  final String? flightPurpose;
  final String? flightArea;
  final String? maxAltitude;
  final String? weather;
  final String? windSpeed;
  final String? temperature;
  final String? notes;
  final List<int> supervisorIds;
  final List<String> supervisorNames;
  // Phase 4.5: 飛行メモ拡張フィールド
  final int? batteryBefore;       // バッテリー飛行前 %
  final int? batteryAfter;        // バッテリー飛行後 %
  final String? batteryNumber;    // バッテリーNo
  final String? flightDistance;   // 飛行距離 (m)
  final String? ownerConsent;     // 所有者や管理者の承諾・許可申請関連
  // Phase 4.5: 座標データ
  final double? takeoffLatitude;
  final double? takeoffLongitude;
  final double? landingLatitude;
  final double? landingLongitude;
  // Phase 4.5: 遵守事項チェックリスト結果
  final Map<String, bool> complianceChecks;
  // Phase 4.5: 許可承認情報
  final String? permitName;
  final String? permitNumber;
  final String? permitStartDate;
  final String? permitEndDate;
  final String? permitItems;
  final String? permitNotes;
  // 飛行の安全に影響のあった事項・不具合事項
  final String? safetyIncident;    // 飛行の安全に影響のあった事項
  final String? defectDetail;      // 不具合事項
  // Phase 4.5: 写真添付データ（Base64エンコード）
  final List<Map<String, String>> photoAttachments; // [{name, data}]
  // Phase 4.5: PDF添付データ（Base64エンコード）
  final List<Map<String, String>> pdfAttachments;   // [{name, data}]
  final String createdAt;
  final String updatedAt;

  FlightRecordData({
    required this.id,
    required this.aircraftId,
    required this.pilotId,
    required this.flightDate,
    this.takeoffTime,
    this.landingTime,
    this.flightDuration,
    this.takeoffLocation,
    this.landingLocation,
    this.flightPurpose,
    this.flightArea,
    this.maxAltitude,
    this.weather,
    this.windSpeed,
    this.temperature,
    this.notes,
    this.supervisorIds = const [],
    this.supervisorNames = const [],
    this.batteryBefore,
    this.batteryAfter,
    this.batteryNumber,
    this.flightDistance,
    this.ownerConsent,
    this.takeoffLatitude,
    this.takeoffLongitude,
    this.landingLatitude,
    this.landingLongitude,
    this.complianceChecks = const {},
    this.permitName,
    this.permitNumber,
    this.permitStartDate,
    this.permitEndDate,
    this.permitItems,
    this.permitNotes,
    this.safetyIncident,
    this.defectDetail,
    this.photoAttachments = const [],
    this.pdfAttachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'aircraftId': aircraftId,
    'pilotId': pilotId,
    'flightDate': flightDate,
    'takeoffTime': takeoffTime,
    'landingTime': landingTime,
    'flightDuration': flightDuration,
    'takeoffLocation': takeoffLocation,
    'landingLocation': landingLocation,
    'flightPurpose': flightPurpose,
    'flightArea': flightArea,
    'maxAltitude': maxAltitude,
    'weather': weather,
    'windSpeed': windSpeed,
    'temperature': temperature,
    'notes': notes,
    'supervisorIds': supervisorIds,
    'supervisorNames': supervisorNames,
    'batteryBefore': batteryBefore,
    'batteryAfter': batteryAfter,
    'batteryNumber': batteryNumber,
    'flightDistance': flightDistance,
    'ownerConsent': ownerConsent,
    'takeoffLatitude': takeoffLatitude,
    'takeoffLongitude': takeoffLongitude,
    'landingLatitude': landingLatitude,
    'landingLongitude': landingLongitude,
    'complianceChecks': complianceChecks,
    'permitName': permitName,
    'permitNumber': permitNumber,
    'permitStartDate': permitStartDate,
    'permitEndDate': permitEndDate,
    'permitItems': permitItems,
    'permitNotes': permitNotes,
    'safetyIncident': safetyIncident,
    'defectDetail': defectDetail,
    'photoAttachments': photoAttachments,
    'pdfAttachments': pdfAttachments,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory FlightRecordData.fromJson(Map<String, dynamic> json) =>
      FlightRecordData(
        id: json['id'] as int,
        aircraftId: json['aircraftId'] as int,
        pilotId: json['pilotId'] as int,
        flightDate: json['flightDate'] as String,
        takeoffTime: json['takeoffTime'] as String?,
        landingTime: json['landingTime'] as String?,
        flightDuration: json['flightDuration'] as int?,
        takeoffLocation: json['takeoffLocation'] as String?,
        landingLocation: json['landingLocation'] as String?,
        flightPurpose: json['flightPurpose'] as String?,
        flightArea: json['flightArea'] as String?,
        maxAltitude: json['maxAltitude'] as String?,
        weather: json['weather'] as String?,
        windSpeed: json['windSpeed'] as String?,
        temperature: json['temperature'] as String?,
        notes: json['notes'] as String?,
        supervisorIds: (json['supervisorIds'] as List<dynamic>?)
            ?.map((e) => e as int).toList() ?? const [],
        supervisorNames: (json['supervisorNames'] as List<dynamic>?)
            ?.map((e) => e as String).toList() ?? const [],
        batteryBefore: json['batteryBefore'] as int?,
        batteryAfter: json['batteryAfter'] as int?,
        batteryNumber: json['batteryNumber'] as String?,
        flightDistance: json['flightDistance'] as String?,
        ownerConsent: json['ownerConsent'] as String?,
        takeoffLatitude: (json['takeoffLatitude'] as num?)?.toDouble(),
        takeoffLongitude: (json['takeoffLongitude'] as num?)?.toDouble(),
        landingLatitude: (json['landingLatitude'] as num?)?.toDouble(),
        landingLongitude: (json['landingLongitude'] as num?)?.toDouble(),
        complianceChecks: (json['complianceChecks'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as bool)) ?? const {},
        permitName: json['permitName'] as String?,
        permitNumber: json['permitNumber'] as String?,
        permitStartDate: json['permitStartDate'] as String?,
        permitEndDate: json['permitEndDate'] as String?,
        permitItems: json['permitItems'] as String?,
        permitNotes: json['permitNotes'] as String?,
        safetyIncident: json['safetyIncident'] as String?,
        defectDetail: json['defectDetail'] as String?,
        photoAttachments: (json['photoAttachments'] as List<dynamic>?)
            ?.map((e) => Map<String, String>.from(e as Map)).toList() ?? const [],
        pdfAttachments: (json['pdfAttachments'] as List<dynamic>?)
            ?.map((e) => Map<String, String>.from(e as Map)).toList() ?? const [],
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );
}

/// 日常点検データクラス（様式2）
class DailyInspectionData {
  final int id;
  final int aircraftId;
  final int inspectorId;
  final String inspectionDate;
  final bool frameCheck;
  final bool propellerCheck;
  final bool motorCheck;
  final bool batteryCheck;
  final bool controllerCheck;
  final bool gpsCheck;
  final bool cameraCheck;
  final bool communicationCheck;
  final String overallResult;
  final String? notes;
  final List<int> supervisorIds;
  final List<String> supervisorNames;
  final String createdAt;
  final String updatedAt;

  DailyInspectionData({
    required this.id,
    required this.aircraftId,
    required this.inspectorId,
    required this.inspectionDate,
    this.frameCheck = false,
    this.propellerCheck = false,
    this.motorCheck = false,
    this.batteryCheck = false,
    this.controllerCheck = false,
    this.gpsCheck = false,
    this.cameraCheck = false,
    this.communicationCheck = false,
    this.overallResult = '合格',
    this.notes,
    this.supervisorIds = const [],
    this.supervisorNames = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'aircraftId': aircraftId,
    'inspectorId': inspectorId,
    'inspectionDate': inspectionDate,
    'frameCheck': frameCheck,
    'propellerCheck': propellerCheck,
    'motorCheck': motorCheck,
    'batteryCheck': batteryCheck,
    'controllerCheck': controllerCheck,
    'gpsCheck': gpsCheck,
    'cameraCheck': cameraCheck,
    'communicationCheck': communicationCheck,
    'overallResult': overallResult,
    'notes': notes,
    'supervisorIds': supervisorIds,
    'supervisorNames': supervisorNames,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory DailyInspectionData.fromJson(Map<String, dynamic> json) =>
      DailyInspectionData(
        id: json['id'] as int,
        aircraftId: json['aircraftId'] as int,
        inspectorId: json['inspectorId'] as int,
        inspectionDate: json['inspectionDate'] as String,
        frameCheck: json['frameCheck'] as bool? ?? false,
        propellerCheck: json['propellerCheck'] as bool? ?? false,
        motorCheck: json['motorCheck'] as bool? ?? false,
        batteryCheck: json['batteryCheck'] as bool? ?? false,
        controllerCheck: json['controllerCheck'] as bool? ?? false,
        gpsCheck: json['gpsCheck'] as bool? ?? false,
        cameraCheck: json['cameraCheck'] as bool? ?? false,
        communicationCheck: json['communicationCheck'] as bool? ?? false,
        overallResult: json['overallResult'] as String? ?? '合格',
        notes: json['notes'] as String?,
        supervisorIds: (json['supervisorIds'] as List<dynamic>?)
            ?.map((e) => e as int).toList() ?? const [],
        supervisorNames: (json['supervisorNames'] as List<dynamic>?)
            ?.map((e) => e as String).toList() ?? const [],
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );
}

/// 整備記録データクラス（様式3）
class MaintenanceRecordData {
  final int id;
  final int aircraftId;
  final int maintainerId;
  final String maintenanceDate;
  final String maintenanceType;
  final String? description;
  final String? partsReplaced;
  final String? result;
  final String? nextMaintenanceDate;
  final String? notes;
  final List<int> supervisorIds;
  final List<String> supervisorNames;
  final String createdAt;
  final String updatedAt;

  MaintenanceRecordData({
    required this.id,
    required this.aircraftId,
    required this.maintainerId,
    required this.maintenanceDate,
    required this.maintenanceType,
    this.description,
    this.partsReplaced,
    this.result,
    this.nextMaintenanceDate,
    this.notes,
    this.supervisorIds = const [],
    this.supervisorNames = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'aircraftId': aircraftId,
    'maintainerId': maintainerId,
    'maintenanceDate': maintenanceDate,
    'maintenanceType': maintenanceType,
    'description': description,
    'partsReplaced': partsReplaced,
    'result': result,
    'nextMaintenanceDate': nextMaintenanceDate,
    'notes': notes,
    'supervisorIds': supervisorIds,
    'supervisorNames': supervisorNames,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory MaintenanceRecordData.fromJson(Map<String, dynamic> json) =>
      MaintenanceRecordData(
        id: json['id'] as int,
        aircraftId: json['aircraftId'] as int,
        maintainerId: json['maintainerId'] as int,
        maintenanceDate: json['maintenanceDate'] as String,
        maintenanceType: json['maintenanceType'] as String,
        description: json['description'] as String?,
        partsReplaced: json['partsReplaced'] as String?,
        result: json['result'] as String?,
        nextMaintenanceDate: json['nextMaintenanceDate'] as String?,
        notes: json['notes'] as String?,
        supervisorIds: (json['supervisorIds'] as List<dynamic>?)
            ?.map((e) => e as int).toList() ?? const [],
        supervisorNames: (json['supervisorNames'] as List<dynamic>?)
            ?.map((e) => e as String).toList() ?? const [],
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );
}

/// 飛行記録ストレージ（SharedPreferences ベース）
class FlightLogStorage {
  late SharedPreferences _prefs;
  int _nextFlightId = 1;
  int _nextInspectionId = 1;
  int _nextMaintenanceId = 1;

  List<FlightRecordData> _flights = [];
  List<DailyInspectionData> _inspections = [];
  List<MaintenanceRecordData> _maintenances = [];

  static const _flightsKey = 'drone_app_flights';
  static const _inspectionsKey = 'drone_app_inspections';
  static const _maintenancesKey = 'drone_app_maintenances';

  static const _seededKey = 'drone_app_flights_seeded';

  /// 初期化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFlights();
    _loadInspections();
    _loadMaintenances();

    // 初回起動時にテスト用サンプルデータを投入
    final alreadySeeded = _prefs.getBool(_seededKey) ?? false;
    if (!alreadySeeded && _flights.isEmpty) {
      await _seedSampleFlights();
      await _prefs.setBool(_seededKey, true);
    }
  }

  /// テスト用サンプル飛行データを投入
  Future<void> _seedSampleFlights() async {
    // 様式1: 飛行実績サンプル（10件・3か月分）
    final sampleFlights = [
      // 2026年2月
      {'date': '2026-02-05', 'aircraft': 1, 'pilot': 1, 'takeoff': '09:00', 'landing': '09:25', 'duration': 25, 'loc': '東京都江東区新木場', 'purpose': '空撮', 'area': '通常飛行', 'alt': '80', 'weather': '晴れ', 'wind': '3', 'temp': '8'},
      {'date': '2026-02-12', 'aircraft': 2, 'pilot': 2, 'takeoff': '10:30', 'landing': '11:00', 'duration': 30, 'loc': '千葉県千葉市美浜区', 'purpose': '測量', 'area': 'DID（人口集中地区）', 'alt': '120', 'weather': '曇り', 'wind': '5', 'temp': '6'},
      {'date': '2026-02-20', 'aircraft': 3, 'pilot': 1, 'takeoff': '14:00', 'landing': '14:40', 'duration': 40, 'loc': '茨城県つくば市', 'purpose': '点検', 'area': '目視外飛行', 'alt': '100', 'weather': '晴れ', 'wind': '2', 'temp': '10'},
      // 2026年3月
      {'date': '2026-03-03', 'aircraft': 1, 'pilot': 3, 'takeoff': '09:15', 'landing': '09:35', 'duration': 20, 'loc': '東京都千代田区', 'purpose': '空撮', 'area': 'DID（人口集中地区）', 'alt': '90', 'weather': '晴れ', 'wind': '4', 'temp': '12'},
      {'date': '2026-03-10', 'aircraft': 4, 'pilot': 2, 'takeoff': '11:00', 'landing': '11:30', 'duration': 30, 'loc': '神奈川県横浜市港北区', 'purpose': '測量', 'area': '通常飛行', 'alt': '100', 'weather': '曇り', 'wind': '3', 'temp': '14'},
      {'date': '2026-03-18', 'aircraft': 2, 'pilot': 1, 'takeoff': '13:30', 'landing': '14:05', 'duration': 35, 'loc': '埼玉県さいたま市緑区', 'purpose': '点検', 'area': '通常飛行', 'alt': '80', 'weather': '晴れ', 'wind': '2', 'temp': '16'},
      {'date': '2026-03-25', 'aircraft': 5, 'pilot': 3, 'takeoff': '10:00', 'landing': '10:45', 'duration': 45, 'loc': '千葉県成田市', 'purpose': '測量', 'area': '目視外飛行', 'alt': '150', 'weather': '晴れ', 'wind': '6', 'temp': '15'},
      // 2026年4月
      {'date': '2026-04-01', 'aircraft': 3, 'pilot': 2, 'takeoff': '09:30', 'landing': '10:10', 'duration': 40, 'loc': '東京都大田区', 'purpose': '点検', 'area': 'DID（人口集中地区）', 'alt': '60', 'weather': '曇り', 'wind': '4', 'temp': '18'},
      {'date': '2026-04-03', 'aircraft': 1, 'pilot': 1, 'takeoff': '15:00', 'landing': '15:20', 'duration': 20, 'loc': '東京都渋谷区', 'purpose': '空撮', 'area': 'DID（人口集中地区）', 'alt': '100', 'weather': '晴れ', 'wind': '3', 'temp': '20'},
      {'date': '2026-04-05', 'aircraft': 4, 'pilot': 3, 'takeoff': '08:00', 'landing': '08:35', 'duration': 35, 'loc': '神奈川県川崎市', 'purpose': '測量', 'area': '通常飛行', 'alt': '120', 'weather': '晴れ', 'wind': '2', 'temp': '19'},
    ];

    for (final f in sampleFlights) {
      await createFlight(
        aircraftId: f['aircraft'] as int,
        pilotId: f['pilot'] as int,
        flightDate: f['date'] as String,
        takeoffTime: f['takeoff'] as String,
        landingTime: f['landing'] as String,
        flightDuration: f['duration'] as int,
        takeoffLocation: f['loc'] as String,
        landingLocation: f['loc'] as String,
        flightPurpose: f['purpose'] as String,
        flightArea: f['area'] as String,
        maxAltitude: f['alt'] as String,
        weather: f['weather'] as String,
        windSpeed: f['wind'] as String,
        temperature: f['temp'] as String,
      );
    }

    // 様式2: 日常点検サンプル（3件）
    await createInspection(
      aircraftId: 1, inspectorId: 1, inspectionDate: '2026-04-01',
      frameCheck: true, propellerCheck: true, motorCheck: true,
      batteryCheck: true, controllerCheck: true, gpsCheck: true,
      cameraCheck: true, communicationCheck: true, overallResult: '合格',
    );
    await createInspection(
      aircraftId: 2, inspectorId: 2, inspectionDate: '2026-04-03',
      frameCheck: true, propellerCheck: true, motorCheck: true,
      batteryCheck: true, controllerCheck: true, gpsCheck: true,
      cameraCheck: false, communicationCheck: true, overallResult: '条件付き合格',
      notes: 'カメラジンバルに若干のぐらつきあり。次回要確認',
    );
    await createInspection(
      aircraftId: 3, inspectorId: 1, inspectionDate: '2026-04-05',
      frameCheck: true, propellerCheck: true, motorCheck: true,
      batteryCheck: true, controllerCheck: true, gpsCheck: true,
      cameraCheck: true, communicationCheck: true, overallResult: '合格',
    );

    // 様式3: 整備記録サンプル（2件）
    await createMaintenance(
      aircraftId: 1, maintainerId: 1, maintenanceDate: '2026-03-15',
      maintenanceType: '定期点検',
      description: 'プロペラ摩耗確認、バッテリーキャリブレーション実施',
      partsReplaced: 'プロペラ4枚交換',
      result: '良好',
      nextMaintenanceDate: '2026-06-15',
    );
    await createMaintenance(
      aircraftId: 3, maintainerId: 3, maintenanceDate: '2026-04-01',
      maintenanceType: 'ファームウェア更新',
      description: 'Matrice 300 RTK ファームウェア v07.00.01.10 適用',
      result: '正常完了',
      nextMaintenanceDate: '2026-07-01',
    );
  }

  // ---- 読み込み ----

  void _loadFlights() {
    try {
      final content = _prefs.getString(_flightsKey);
      if (content != null && content.isNotEmpty) {
        final json = jsonDecode(content) as Map<String, dynamic>;
        final list = json['items'] as List<dynamic>? ?? [];
        _flights = list
            .map((item) =>
                FlightRecordData.fromJson(item as Map<String, dynamic>))
            .toList();
        _nextFlightId = (json['nextId'] as int?) ??
            (_flights.isEmpty
                ? 1
                : _flights.map((f) => f.id).reduce((a, b) => a > b ? a : b) +
                    1);
      }
    } catch (e) {
      _flights = [];
      _nextFlightId = 1;
    }
  }

  void _loadInspections() {
    try {
      final content = _prefs.getString(_inspectionsKey);
      if (content != null && content.isNotEmpty) {
        final json = jsonDecode(content) as Map<String, dynamic>;
        final list = json['items'] as List<dynamic>? ?? [];
        _inspections = list
            .map((item) =>
                DailyInspectionData.fromJson(item as Map<String, dynamic>))
            .toList();
        _nextInspectionId = (json['nextId'] as int?) ??
            (_inspections.isEmpty
                ? 1
                : _inspections
                        .map((i) => i.id)
                        .reduce((a, b) => a > b ? a : b) +
                    1);
      }
    } catch (e) {
      _inspections = [];
      _nextInspectionId = 1;
    }
  }

  void _loadMaintenances() {
    try {
      final content = _prefs.getString(_maintenancesKey);
      if (content != null && content.isNotEmpty) {
        final json = jsonDecode(content) as Map<String, dynamic>;
        final list = json['items'] as List<dynamic>? ?? [];
        _maintenances = list
            .map((item) =>
                MaintenanceRecordData.fromJson(item as Map<String, dynamic>))
            .toList();
        _nextMaintenanceId = (json['nextId'] as int?) ??
            (_maintenances.isEmpty
                ? 1
                : _maintenances
                        .map((m) => m.id)
                        .reduce((a, b) => a > b ? a : b) +
                    1);
      }
    } catch (e) {
      _maintenances = [];
      _nextMaintenanceId = 1;
    }
  }

  // ---- 保存 ----

  Future<void> _saveFlights() async {
    final json = jsonEncode({
      'items': _flights.map((f) => f.toJson()).toList(),
      'nextId': _nextFlightId,
    });
    await _prefs.setString(_flightsKey, json);
  }

  Future<void> _saveInspections() async {
    final json = jsonEncode({
      'items': _inspections.map((i) => i.toJson()).toList(),
      'nextId': _nextInspectionId,
    });
    await _prefs.setString(_inspectionsKey, json);
  }

  Future<void> _saveMaintenances() async {
    final json = jsonEncode({
      'items': _maintenances.map((m) => m.toJson()).toList(),
      'nextId': _nextMaintenanceId,
    });
    await _prefs.setString(_maintenancesKey, json);
  }

  // ---- 飛行実績（様式1）CRUD ----

  Future<List<FlightRecordData>> getAllFlights() async => _flights;

  Future<FlightRecordData?> getFlightById(int id) async {
    try {
      return _flights.firstWhere((f) => f.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<int> createFlight({
    required int aircraftId,
    required int pilotId,
    required String flightDate,
    String? takeoffTime,
    String? landingTime,
    int? flightDuration,
    String? takeoffLocation,
    String? landingLocation,
    String? flightPurpose,
    String? flightArea,
    String? maxAltitude,
    String? weather,
    String? windSpeed,
    String? temperature,
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
    int? batteryBefore,
    int? batteryAfter,
    String? batteryNumber,
    String? flightDistance,
    String? ownerConsent,
    double? takeoffLatitude,
    double? takeoffLongitude,
    double? landingLatitude,
    double? landingLongitude,
    Map<String, bool> complianceChecks = const {},
    String? permitName,
    String? permitNumber,
    String? permitStartDate,
    String? permitEndDate,
    String? permitItems,
    String? permitNotes,
    String? safetyIncident,
    String? defectDetail,
    List<Map<String, String>> photoAttachments = const [],
    List<Map<String, String>> pdfAttachments = const [],
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _nextFlightId;
    _nextFlightId++;

    _flights.add(FlightRecordData(
      id: id,
      aircraftId: aircraftId,
      pilotId: pilotId,
      flightDate: flightDate,
      takeoffTime: takeoffTime,
      landingTime: landingTime,
      flightDuration: flightDuration,
      takeoffLocation: takeoffLocation,
      landingLocation: landingLocation,
      flightPurpose: flightPurpose,
      flightArea: flightArea,
      maxAltitude: maxAltitude,
      weather: weather,
      windSpeed: windSpeed,
      temperature: temperature,
      notes: notes,
      supervisorIds: supervisorIds,
      supervisorNames: supervisorNames,
      batteryBefore: batteryBefore,
      batteryAfter: batteryAfter,
      batteryNumber: batteryNumber,
      flightDistance: flightDistance,
      ownerConsent: ownerConsent,
      takeoffLatitude: takeoffLatitude,
      takeoffLongitude: takeoffLongitude,
      landingLatitude: landingLatitude,
      landingLongitude: landingLongitude,
      complianceChecks: complianceChecks,
      permitName: permitName,
      permitNumber: permitNumber,
      permitStartDate: permitStartDate,
      permitEndDate: permitEndDate,
      permitItems: permitItems,
      permitNotes: permitNotes,
      safetyIncident: safetyIncident,
      defectDetail: defectDetail,
      photoAttachments: photoAttachments,
      pdfAttachments: pdfAttachments,
      createdAt: now,
      updatedAt: now,
    ));
    await _saveFlights();
    return id;
  }

  /// CSVから飛行記録を一括インポート
  /// 各レコードはMap<String, String>で、キーはCSVヘッダーに対応するフィールド名
  Future<int> importFlights(List<Map<String, String>> records) async {
    var imported = 0;
    for (final r in records) {
      final flightDate = r['flightDate'] ?? '';
      if (flightDate.isEmpty) continue;

      final aircraftId = int.tryParse(r['aircraftId'] ?? '') ?? 1;
      final pilotId = int.tryParse(r['pilotId'] ?? '') ?? 1;
      final durationStr = r['flightDuration'] ?? '';
      final duration = durationStr.isNotEmpty ? int.tryParse(durationStr) : null;

      await createFlight(
        aircraftId: aircraftId,
        pilotId: pilotId,
        flightDate: flightDate,
        takeoffTime: _nullIfEmpty(r['takeoffTime']),
        landingTime: _nullIfEmpty(r['landingTime']),
        flightDuration: duration,
        takeoffLocation: _nullIfEmpty(r['takeoffLocation']),
        landingLocation: _nullIfEmpty(r['landingLocation']),
        flightPurpose: _nullIfEmpty(r['flightPurpose']),
        flightArea: _nullIfEmpty(r['flightArea']),
        maxAltitude: _nullIfEmpty(r['maxAltitude']),
        weather: _nullIfEmpty(r['weather']),
        windSpeed: _nullIfEmpty(r['windSpeed']),
        temperature: _nullIfEmpty(r['temperature']),
        notes: _nullIfEmpty(r['notes']),
      );
      imported++;
    }
    return imported;
  }

  /// 空文字列をnullに変換するヘルパー
  static String? _nullIfEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  /// 飛行記録を更新する
  Future<bool> updateFlight({
    required int id,
    required int aircraftId,
    required int pilotId,
    required String flightDate,
    String? takeoffTime,
    String? landingTime,
    int? flightDuration,
    String? takeoffLocation,
    String? landingLocation,
    String? flightPurpose,
    String? flightArea,
    String? maxAltitude,
    String? weather,
    String? windSpeed,
    String? temperature,
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
    int? batteryBefore,
    int? batteryAfter,
    String? batteryNumber,
    String? flightDistance,
    String? ownerConsent,
    double? takeoffLatitude,
    double? takeoffLongitude,
    double? landingLatitude,
    double? landingLongitude,
    Map<String, bool> complianceChecks = const {},
    String? permitName,
    String? permitNumber,
    String? permitStartDate,
    String? permitEndDate,
    String? permitItems,
    String? permitNotes,
    String? safetyIncident,
    String? defectDetail,
    List<Map<String, String>> photoAttachments = const [],
    List<Map<String, String>> pdfAttachments = const [],
  }) async {
    final index = _flights.indexWhere((f) => f.id == id);
    if (index == -1) return false;

    final existing = _flights[index];
    final now = DateTime.now().toIso8601String();

    _flights[index] = FlightRecordData(
      id: id,
      aircraftId: aircraftId,
      pilotId: pilotId,
      flightDate: flightDate,
      takeoffTime: takeoffTime,
      landingTime: landingTime,
      flightDuration: flightDuration,
      takeoffLocation: takeoffLocation,
      landingLocation: landingLocation,
      flightPurpose: flightPurpose,
      flightArea: flightArea,
      maxAltitude: maxAltitude,
      weather: weather,
      windSpeed: windSpeed,
      temperature: temperature,
      notes: notes,
      supervisorIds: supervisorIds,
      supervisorNames: supervisorNames,
      batteryBefore: batteryBefore,
      batteryAfter: batteryAfter,
      batteryNumber: batteryNumber,
      flightDistance: flightDistance,
      ownerConsent: ownerConsent,
      takeoffLatitude: takeoffLatitude,
      takeoffLongitude: takeoffLongitude,
      landingLatitude: landingLatitude,
      landingLongitude: landingLongitude,
      complianceChecks: complianceChecks,
      permitName: permitName,
      permitNumber: permitNumber,
      permitStartDate: permitStartDate,
      permitEndDate: permitEndDate,
      permitItems: permitItems,
      permitNotes: permitNotes,
      safetyIncident: safetyIncident,
      defectDetail: defectDetail,
      photoAttachments: photoAttachments,
      pdfAttachments: pdfAttachments,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await _saveFlights();
    return true;
  }

  Future<bool> deleteFlight(int id) async {
    final index = _flights.indexWhere((f) => f.id == id);
    if (index == -1) return false;
    _flights.removeAt(index);
    await _saveFlights();
    return true;
  }

  // ---- 日常点検（様式2）CRUD ----

  Future<List<DailyInspectionData>> getAllInspections() async => _inspections;

  Future<DailyInspectionData?> getInspectionById(int id) async {
    try {
      return _inspections.firstWhere((i) => i.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<int> createInspection({
    required int aircraftId,
    required int inspectorId,
    required String inspectionDate,
    bool frameCheck = false,
    bool propellerCheck = false,
    bool motorCheck = false,
    bool batteryCheck = false,
    bool controllerCheck = false,
    bool gpsCheck = false,
    bool cameraCheck = false,
    bool communicationCheck = false,
    String overallResult = '合格',
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _nextInspectionId;
    _nextInspectionId++;

    _inspections.add(DailyInspectionData(
      id: id,
      aircraftId: aircraftId,
      inspectorId: inspectorId,
      inspectionDate: inspectionDate,
      frameCheck: frameCheck,
      propellerCheck: propellerCheck,
      motorCheck: motorCheck,
      batteryCheck: batteryCheck,
      controllerCheck: controllerCheck,
      gpsCheck: gpsCheck,
      cameraCheck: cameraCheck,
      communicationCheck: communicationCheck,
      overallResult: overallResult,
      notes: notes,
      supervisorIds: supervisorIds,
      supervisorNames: supervisorNames,
      createdAt: now,
      updatedAt: now,
    ));
    await _saveInspections();
    return id;
  }

  /// 日常点検記録を更新する
  Future<bool> updateInspection({
    required int id,
    required int aircraftId,
    required int inspectorId,
    required String inspectionDate,
    bool frameCheck = false,
    bool propellerCheck = false,
    bool motorCheck = false,
    bool batteryCheck = false,
    bool controllerCheck = false,
    bool gpsCheck = false,
    bool cameraCheck = false,
    bool communicationCheck = false,
    String overallResult = '合格',
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
  }) async {
    final index = _inspections.indexWhere((i) => i.id == id);
    if (index == -1) return false;
    final existing = _inspections[index];
    final now = DateTime.now().toIso8601String();
    _inspections[index] = DailyInspectionData(
      id: id,
      aircraftId: aircraftId,
      inspectorId: inspectorId,
      inspectionDate: inspectionDate,
      frameCheck: frameCheck,
      propellerCheck: propellerCheck,
      motorCheck: motorCheck,
      batteryCheck: batteryCheck,
      controllerCheck: controllerCheck,
      gpsCheck: gpsCheck,
      cameraCheck: cameraCheck,
      communicationCheck: communicationCheck,
      overallResult: overallResult,
      notes: notes,
      supervisorIds: supervisorIds,
      supervisorNames: supervisorNames,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await _saveInspections();
    return true;
  }

  Future<bool> deleteInspection(int id) async {
    final index = _inspections.indexWhere((i) => i.id == id);
    if (index == -1) return false;
    _inspections.removeAt(index);
    await _saveInspections();
    return true;
  }

  // ---- 整備記録（様式3）CRUD ----

  Future<List<MaintenanceRecordData>> getAllMaintenances() async =>
      _maintenances;

  Future<MaintenanceRecordData?> getMaintenanceById(int id) async {
    try {
      return _maintenances.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<int> createMaintenance({
    required int aircraftId,
    required int maintainerId,
    required String maintenanceDate,
    required String maintenanceType,
    String? description,
    String? partsReplaced,
    String? result,
    String? nextMaintenanceDate,
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _nextMaintenanceId;
    _nextMaintenanceId++;

    _maintenances.add(MaintenanceRecordData(
      id: id,
      aircraftId: aircraftId,
      maintainerId: maintainerId,
      maintenanceDate: maintenanceDate,
      maintenanceType: maintenanceType,
      description: description,
      partsReplaced: partsReplaced,
      result: result,
      nextMaintenanceDate: nextMaintenanceDate,
      notes: notes,
      supervisorIds: supervisorIds,
      supervisorNames: supervisorNames,
      createdAt: now,
      updatedAt: now,
    ));
    await _saveMaintenances();
    return id;
  }

  /// 整備記録を更新する
  Future<bool> updateMaintenance({
    required int id,
    required int aircraftId,
    required int maintainerId,
    required String maintenanceDate,
    required String maintenanceType,
    String? description,
    String? partsReplaced,
    String? result,
    String? nextMaintenanceDate,
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
  }) async {
    final index = _maintenances.indexWhere((m) => m.id == id);
    if (index == -1) return false;
    final existing = _maintenances[index];
    final now = DateTime.now().toIso8601String();
    _maintenances[index] = MaintenanceRecordData(
      id: id,
      aircraftId: aircraftId,
      maintainerId: maintainerId,
      maintenanceDate: maintenanceDate,
      maintenanceType: maintenanceType,
      description: description,
      partsReplaced: partsReplaced,
      result: result,
      nextMaintenanceDate: nextMaintenanceDate,
      notes: notes,
      supervisorIds: supervisorIds,
      supervisorNames: supervisorNames,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await _saveMaintenances();
    return true;
  }

  Future<bool> deleteMaintenance(int id) async {
    final index = _maintenances.indexWhere((m) => m.id == id);
    if (index == -1) return false;
    _maintenances.removeAt(index);
    await _saveMaintenances();
    return true;
  }
}
