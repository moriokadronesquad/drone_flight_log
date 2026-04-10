import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 住所履歴データクラス
class LocationHistoryData {
  final int id;
  final String address;
  final double? latitude;
  final double? longitude;
  final int usedCount;
  final String lastUsedAt;

  LocationHistoryData({
    required this.id,
    required this.address,
    this.latitude,
    this.longitude,
    this.usedCount = 1,
    required this.lastUsedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'usedCount': usedCount,
    'lastUsedAt': lastUsedAt,
  };

  factory LocationHistoryData.fromJson(Map<String, dynamic> json) =>
      LocationHistoryData(
        id: json['id'] as int,
        address: json['address'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        usedCount: json['usedCount'] as int? ?? 1,
        lastUsedAt: json['lastUsedAt'] as String,
      );

  LocationHistoryData copyWith({
    int? usedCount,
    String? lastUsedAt,
  }) {
    return LocationHistoryData(
      id: id,
      address: address,
      latitude: latitude,
      longitude: longitude,
      usedCount: usedCount ?? this.usedCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}

/// 住所履歴ストレージ
class LocationHistoryStorage {
  late SharedPreferences _prefs;
  int _nextId = 1;
  List<LocationHistoryData> _histories = [];

  static const _storageKey = 'drone_app_location_history';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    try {
      final content = _prefs.getString(_storageKey);
      if (content != null && content.isNotEmpty) {
        final json = jsonDecode(content) as Map<String, dynamic>;
        final list = json['items'] as List<dynamic>? ?? [];
        _histories = list
            .map((item) =>
                LocationHistoryData.fromJson(item as Map<String, dynamic>))
            .toList();
        _nextId = (json['nextId'] as int?) ??
            (_histories.isEmpty
                ? 1
                : _histories.map((h) => h.id).reduce((a, b) => a > b ? a : b) + 1);
      }
    } catch (e) {
      _histories = [];
      _nextId = 1;
    }
  }

  Future<void> _save() async {
    final json = jsonEncode({
      'items': _histories.map((h) => h.toJson()).toList(),
      'nextId': _nextId,
    });
    await _prefs.setString(_storageKey, json);
  }

  /// 住所履歴一覧（使用回数順）
  Future<List<LocationHistoryData>> getAll() async {
    final sorted = List<LocationHistoryData>.from(_histories);
    sorted.sort((a, b) => b.usedCount.compareTo(a.usedCount));
    return sorted;
  }

  /// 住所を記録（既存なら使用回数を増加）
  Future<void> recordLocation({
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    // 同じ住所が既にあるか確認
    final existingIdx = _histories.indexWhere((h) => h.address == address);

    if (existingIdx >= 0) {
      // 既存の住所の使用回数を増加
      final existing = _histories[existingIdx];
      _histories[existingIdx] = existing.copyWith(
        usedCount: existing.usedCount + 1,
        lastUsedAt: DateTime.now().toIso8601String(),
      );
    } else {
      // 新規追加
      _histories.add(LocationHistoryData(
        id: _nextId++,
        address: address,
        latitude: latitude,
        longitude: longitude,
        lastUsedAt: DateTime.now().toIso8601String(),
      ));
    }

    await _save();
  }

  /// 履歴を削除
  Future<void> deleteHistory(int id) async {
    _histories.removeWhere((h) => h.id == id);
    await _save();
  }

  /// 全履歴を削除
  Future<void> clearAll() async {
    _histories.clear();
    _nextId = 1;
    await _save();
  }
}
