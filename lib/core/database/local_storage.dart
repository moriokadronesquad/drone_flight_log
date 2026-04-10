import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// パイロットデータクラス
class PilotData {
  final int id;
  final String name;
  final String? licenseNumber;
  final String? licenseType;
  final String? licenseExpiry;
  final String? organization;
  final String? contact;
  // Phase 4.5: 技能証明書フィールド
  final String? certificateNumber;         // 技能証明書番号
  final String? certificateIssueDate;      // 技能証明書交付日
  final String? certificateRegistrationDate; // 技能証明書登録日
  final bool autoRegister;                 // 新規作成時に自動登録
  final String createdAt;
  final String updatedAt;

  PilotData({
    required this.id,
    required this.name,
    this.licenseNumber,
    this.licenseType,
    this.licenseExpiry,
    this.organization,
    this.contact,
    this.certificateNumber,
    this.certificateIssueDate,
    this.certificateRegistrationDate,
    this.autoRegister = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'licenseNumber': licenseNumber,
    'licenseType': licenseType,
    'licenseExpiry': licenseExpiry,
    'organization': organization,
    'contact': contact,
    'certificateNumber': certificateNumber,
    'certificateIssueDate': certificateIssueDate,
    'certificateRegistrationDate': certificateRegistrationDate,
    'autoRegister': autoRegister,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory PilotData.fromJson(Map<String, dynamic> json) => PilotData(
    id: json['id'] as int,
    name: json['name'] as String,
    licenseNumber: json['licenseNumber'] as String?,
    licenseType: json['licenseType'] as String?,
    licenseExpiry: json['licenseExpiry'] as String?,
    organization: json['organization'] as String?,
    contact: json['contact'] as String?,
    certificateNumber: json['certificateNumber'] as String?,
    certificateIssueDate: json['certificateIssueDate'] as String?,
    certificateRegistrationDate: json['certificateRegistrationDate'] as String?,
    autoRegister: json['autoRegister'] as bool? ?? false,
    createdAt: json['createdAt'] as String,
    updatedAt: json['updatedAt'] as String,
  );
}

/// 航空機データクラス
class AircraftData {
  final int id;
  final String registrationNumber;
  final String aircraftType;
  final String? manufacturer;
  final String? modelName;
  final String? serialNumber;
  final double? maxTakeoffWeight;
  final int totalFlightTime;
  final String? imageUrl;
  final String createdAt;
  final String updatedAt;

  AircraftData({
    required this.id,
    required this.registrationNumber,
    required this.aircraftType,
    this.manufacturer,
    this.modelName,
    this.serialNumber,
    this.maxTakeoffWeight,
    required this.totalFlightTime,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'registrationNumber': registrationNumber,
    'aircraftType': aircraftType,
    'manufacturer': manufacturer,
    'modelName': modelName,
    'serialNumber': serialNumber,
    'maxTakeoffWeight': maxTakeoffWeight,
    'totalFlightTime': totalFlightTime,
    'imageUrl': imageUrl,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory AircraftData.fromJson(Map<String, dynamic> json) => AircraftData(
    id: json['id'] as int,
    registrationNumber: json['registrationNumber'] as String,
    aircraftType: json['aircraftType'] as String,
    manufacturer: json['manufacturer'] as String?,
    modelName: json['modelName'] as String?,
    serialNumber: json['serialNumber'] as String?,
    maxTakeoffWeight: (json['maxTakeoffWeight'] as num?)?.toDouble(),
    totalFlightTime: json['totalFlightTime'] as int? ?? 0,
    imageUrl: json['imageUrl'] as String?,
    createdAt: json['createdAt'] as String,
    updatedAt: json['updatedAt'] as String,
  );
}

/// ローカルストレージ実装（SharedPreferences ベース）
/// Web・iOS・Android すべてで動作する
class LocalStorage {
  late SharedPreferences _prefs;
  int _nextPilotId = 1;
  int _nextAircraftId = 1;

  List<PilotData> _pilots = [];
  List<AircraftData> _aircrafts = [];

  /// SharedPreferencesのキー
  static const _pilotsKey = 'drone_app_pilots';
  static const _aircraftsKey = 'drone_app_aircrafts';

  /// シードデータ投入済みフラグのキー
  static const _seededKey = 'drone_app_seeded';

  /// 初期化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadPilots();
    _loadAircrafts();

    // 初回起動時にテスト用サンプルデータを投入
    final alreadySeeded = _prefs.getBool(_seededKey) ?? false;
    if (!alreadySeeded && _pilots.isEmpty && _aircrafts.isEmpty) {
      await _seedDefaultData();
      await _prefs.setBool(_seededKey, true);
    }
  }

  /// テスト用サンプルデータを投入
  Future<void> _seedDefaultData() async {
    // ---- サンプル機体データ（5件） ----
    await createAircraft(
      registrationNumber: 'JU-001',
      aircraftType: 'マルチローター',
      manufacturer: 'DJI',
      modelName: 'Mavic 3',
      serialNumber: 'DJI-M3-20240101',
      maxTakeoffWeight: 0.895,
    );
    await createAircraft(
      registrationNumber: 'JU-002',
      aircraftType: 'マルチローター',
      manufacturer: 'DJI',
      modelName: 'Phantom 4 RTK',
      serialNumber: 'DJI-P4R-20230515',
      maxTakeoffWeight: 1.391,
    );
    await createAircraft(
      registrationNumber: 'JU-003',
      aircraftType: 'マルチローター',
      manufacturer: 'DJI',
      modelName: 'Matrice 300 RTK',
      serialNumber: 'DJI-M300-20230801',
      maxTakeoffWeight: 9,
    );
    await createAircraft(
      registrationNumber: 'JU-004',
      aircraftType: 'マルチローター',
      manufacturer: 'Autel Robotics',
      modelName: 'EVO II Pro V3',
      serialNumber: 'AUT-E2P-20240301',
      maxTakeoffWeight: 1.25,
    );
    await createAircraft(
      registrationNumber: 'JU-005',
      aircraftType: '固定翼',
      manufacturer: 'senseFly',
      modelName: 'eBee X',
      serialNumber: 'SF-EBX-20231201',
      maxTakeoffWeight: 1.6,
    );

    // ---- サンプル操縦者データ（3件） ----
    await createPilot(
      name: '山田 太郎',
      licenseNumber: 'UA-2024-00001',
      licenseType: '一等無人航空機操縦士',
      licenseExpiry: '2027-03-31',
      organization: '湊運輸倉庫株式会社',
      contact: '090-1234-5678',
    );
    await createPilot(
      name: '佐藤 花子',
      licenseNumber: 'UA-2024-00045',
      licenseType: '二等無人航空機操縦士',
      licenseExpiry: '2026-09-30',
      organization: '湊運輸倉庫株式会社',
      contact: '080-9876-5432',
    );
    await createPilot(
      name: '鈴木 一郎',
      licenseNumber: 'UA-2023-00120',
      licenseType: '一等無人航空機操縦士',
      licenseExpiry: '2026-06-15',
      organization: '湊運輸倉庫株式会社',
      contact: '070-1111-2222',
    );
  }

  /// パイロットデータを読み込み
  void _loadPilots() {
    try {
      final content = _prefs.getString(_pilotsKey);
      if (content != null && content.isNotEmpty) {
        final json = jsonDecode(content) as Map<String, dynamic>;
        final pilotsJson = json['pilots'] as List<dynamic>? ?? [];
        _pilots = pilotsJson
            .map((item) => PilotData.fromJson(item as Map<String, dynamic>))
            .toList();
        _nextPilotId = (json['nextId'] as int?) ??
            (_pilots.isEmpty
                ? 1
                : _pilots.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1);
      }
    } catch (e) {
      _pilots = [];
      _nextPilotId = 1;
    }
  }

  /// 航空機データを読み込み
  void _loadAircrafts() {
    try {
      final content = _prefs.getString(_aircraftsKey);
      if (content != null && content.isNotEmpty) {
        final json = jsonDecode(content) as Map<String, dynamic>;
        final aircraftsJson = json['aircrafts'] as List<dynamic>? ?? [];
        _aircrafts = aircraftsJson
            .map((item) => AircraftData.fromJson(item as Map<String, dynamic>))
            .toList();
        _nextAircraftId = (json['nextId'] as int?) ??
            (_aircrafts.isEmpty
                ? 1
                : _aircrafts.map((a) => a.id).reduce((a, b) => a > b ? a : b) + 1);
      }
    } catch (e) {
      _aircrafts = [];
      _nextAircraftId = 1;
    }
  }

  /// パイロットデータを保存
  Future<void> _savePilots() async {
    final json = jsonEncode({
      'pilots': _pilots.map((p) => p.toJson()).toList(),
      'nextId': _nextPilotId,
    });
    await _prefs.setString(_pilotsKey, json);
  }

  /// 航空機データを保存
  Future<void> _saveAircrafts() async {
    final json = jsonEncode({
      'aircrafts': _aircrafts.map((a) => a.toJson()).toList(),
      'nextId': _nextAircraftId,
    });
    await _prefs.setString(_aircraftsKey, json);
  }

  // ---- パイロット関連のメソッド ----

  Future<List<PilotData>> getAllPilots() async {
    return _pilots;
  }

  Future<PilotData?> getPilotById(int id) async {
    try {
      return _pilots.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<int> createPilot({
    required String name,
    String? licenseNumber,
    String? licenseType,
    String? licenseExpiry,
    String? organization,
    String? contact,
    String? certificateNumber,
    String? certificateIssueDate,
    String? certificateRegistrationDate,
    bool autoRegister = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _nextPilotId;
    _nextPilotId++;

    final pilot = PilotData(
      id: id,
      name: name,
      licenseNumber: licenseNumber,
      licenseType: licenseType,
      licenseExpiry: licenseExpiry,
      organization: organization,
      contact: contact,
      certificateNumber: certificateNumber,
      certificateIssueDate: certificateIssueDate,
      certificateRegistrationDate: certificateRegistrationDate,
      autoRegister: autoRegister,
      createdAt: now,
      updatedAt: now,
    );

    _pilots.add(pilot);
    await _savePilots();
    return id;
  }

  Future<bool> updatePilot({
    required int id,
    required String name,
    String? licenseNumber,
    String? licenseType,
    String? licenseExpiry,
    String? organization,
    String? contact,
    String? certificateNumber,
    String? certificateIssueDate,
    String? certificateRegistrationDate,
    bool autoRegister = false,
  }) async {
    final index = _pilots.indexWhere((p) => p.id == id);
    if (index == -1) return false;

    final now = DateTime.now().toIso8601String();
    final existing = _pilots[index];

    _pilots[index] = PilotData(
      id: id,
      name: name,
      licenseNumber: licenseNumber,
      licenseType: licenseType,
      licenseExpiry: licenseExpiry,
      organization: organization,
      contact: contact,
      certificateNumber: certificateNumber,
      certificateIssueDate: certificateIssueDate,
      certificateRegistrationDate: certificateRegistrationDate,
      autoRegister: autoRegister,
      createdAt: existing.createdAt,
      updatedAt: now,
    );

    await _savePilots();
    return true;
  }

  Future<bool> deletePilot(int id) async {
    final index = _pilots.indexWhere((p) => p.id == id);
    if (index == -1) return false;

    _pilots.removeAt(index);
    await _savePilots();
    return true;
  }

  // ---- 航空機関連のメソッド ----

  Future<List<AircraftData>> getAllAircrafts() async {
    return _aircrafts;
  }

  Future<AircraftData?> getAircraftById(int id) async {
    try {
      return _aircrafts.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<int> createAircraft({
    required String registrationNumber,
    required String aircraftType,
    String? manufacturer,
    String? modelName,
    String? serialNumber,
    double? maxTakeoffWeight,
    String? imageUrl,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _nextAircraftId;
    _nextAircraftId++;

    final aircraft = AircraftData(
      id: id,
      registrationNumber: registrationNumber,
      aircraftType: aircraftType,
      manufacturer: manufacturer,
      modelName: modelName,
      serialNumber: serialNumber,
      maxTakeoffWeight: maxTakeoffWeight,
      totalFlightTime: 0,
      imageUrl: imageUrl,
      createdAt: now,
      updatedAt: now,
    );

    _aircrafts.add(aircraft);
    await _saveAircrafts();
    return id;
  }

  Future<bool> updateAircraft({
    required int id,
    required String registrationNumber,
    required String aircraftType,
    String? manufacturer,
    String? modelName,
    String? serialNumber,
    double? maxTakeoffWeight,
    String? imageUrl,
  }) async {
    final index = _aircrafts.indexWhere((a) => a.id == id);
    if (index == -1) return false;

    final now = DateTime.now().toIso8601String();
    final existing = _aircrafts[index];

    _aircrafts[index] = AircraftData(
      id: id,
      registrationNumber: registrationNumber,
      aircraftType: aircraftType,
      manufacturer: manufacturer,
      modelName: modelName,
      serialNumber: serialNumber,
      maxTakeoffWeight: maxTakeoffWeight,
      totalFlightTime: existing.totalFlightTime,
      imageUrl: imageUrl,
      createdAt: existing.createdAt,
      updatedAt: now,
    );

    await _saveAircrafts();
    return true;
  }

  Future<bool> deleteAircraft(int id) async {
    final index = _aircrafts.indexWhere((a) => a.id == id);
    if (index == -1) return false;

    _aircrafts.removeAt(index);
    await _saveAircrafts();
    return true;
  }

  // ---- 全データクリア用メソッド ----

  /// 全機体データを削除する（スプレッドシート同期前のクリーンアップ用）
  Future<void> clearAllAircrafts() async {
    _aircrafts.clear();
    _nextAircraftId = 1;
    await _saveAircrafts();
  }

  /// 全操縦者データを削除する（スプレッドシート同期前のクリーンアップ用）
  Future<void> clearAllPilots() async {
    _pilots.clear();
    _nextPilotId = 1;
    await _savePilots();
  }

  // ---- エクスポート用メソッド ----

  /// 全パイロットデータを取得（エクスポート用）
  List<PilotData> getAllPilotsSync() => List.unmodifiable(_pilots);

  /// 全航空機データを取得（エクスポート用）
  List<AircraftData> getAllAircraftsSync() => List.unmodifiable(_aircrafts);

  // ---- バルクインポート用メソッド ----

  /// 複数の機体を一括インポート
  /// 返り値: インポートされた件数
  Future<int> importAircrafts(List<Map<String, String>> dataList) async {
    var count = 0;
    for (final data in dataList) {
      final regNum = data['registrationNumber'] ?? '';
      if (regNum.isEmpty) continue;

      await createAircraft(
        registrationNumber: regNum,
        aircraftType: data['aircraftType']?.isNotEmpty == true
            ? data['aircraftType']!
            : 'マルチローター',
        manufacturer:
            data['manufacturer']?.isNotEmpty == true ? data['manufacturer'] : null,
        modelName:
            data['modelName']?.isNotEmpty == true ? data['modelName'] : null,
        serialNumber:
            data['serialNumber']?.isNotEmpty == true ? data['serialNumber'] : null,
        maxTakeoffWeight: data['maxTakeoffWeight']?.isNotEmpty == true
            ? double.tryParse(data['maxTakeoffWeight']!)
            : null,
      );
      count++;
    }
    return count;
  }

  /// 複数の操縦者を一括インポート
  /// 返り値: インポートされた件数
  Future<int> importPilots(List<Map<String, String>> dataList) async {
    var count = 0;
    for (final data in dataList) {
      final name = data['name'] ?? '';
      if (name.isEmpty) continue;

      await createPilot(
        name: name,
        licenseNumber:
            data['licenseNumber']?.isNotEmpty == true ? data['licenseNumber'] : null,
        licenseType:
            data['licenseType']?.isNotEmpty == true ? data['licenseType'] : null,
        licenseExpiry:
            data['licenseExpiry']?.isNotEmpty == true ? data['licenseExpiry'] : null,
        organization:
            data['organization']?.isNotEmpty == true ? data['organization'] : null,
        contact: data['contact']?.isNotEmpty == true ? data['contact'] : null,
        certificateNumber:
            data['certificateNumber']?.isNotEmpty == true ? data['certificateNumber'] : null,
        certificateIssueDate:
            data['certificateIssueDate']?.isNotEmpty == true ? data['certificateIssueDate'] : null,
        certificateRegistrationDate:
            data['certificateRegistrationDate']?.isNotEmpty == true ? data['certificateRegistrationDate'] : null,
        autoRegister: data['autoRegister'] == 'true',
      );
      count++;
    }
    return count;
  }
}

/// LocalStorageプロバイダ
final localStorageProvider = FutureProvider<LocalStorage>((ref) async {
  final storage = LocalStorage();
  await storage.init();
  return storage;
});
