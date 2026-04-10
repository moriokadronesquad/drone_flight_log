import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// お気に入り場所データ
class FavoriteLocation {
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final int useCount;

  FavoriteLocation({
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.useCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'useCount': useCount,
      };

  factory FavoriteLocation.fromJson(Map<String, dynamic> json) {
    return FavoriteLocation(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      useCount: json['useCount'] as int? ?? 0,
    );
  }

  /// 使用回数をインクリメントしたコピーを返す
  FavoriteLocation incrementUse() => FavoriteLocation(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        useCount: useCount + 1,
      );
}

/// よく使う離着陸場所を管理するサービス
class FavoriteLocationService {
  static const _key = 'favorite_locations';

  /// お気に入り場所一覧を取得（使用回数の多い順）
  static Future<List<FavoriteLocation>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> list = json.decode(jsonStr);
      final locations = list
          .map((e) => FavoriteLocation.fromJson(e as Map<String, dynamic>))
          .toList();
      locations.sort((a, b) => b.useCount.compareTo(a.useCount));
      return locations;
    } catch (_) {
      return [];
    }
  }

  /// お気に入り場所を追加
  static Future<void> add(FavoriteLocation location) async {
    final locations = await getAll();
    // 同じ住所が既にあれば追加しない
    if (locations.any((l) => l.address == location.address)) return;
    locations.add(location);
    await _save(locations);
  }

  /// お気に入り場所を削除
  static Future<void> remove(String address) async {
    final locations = await getAll();
    locations.removeWhere((l) => l.address == address);
    await _save(locations);
  }

  /// 使用回数をインクリメント
  static Future<void> recordUse(String address) async {
    final locations = await getAll();
    final index = locations.indexWhere((l) => l.address == address);
    if (index >= 0) {
      locations[index] = locations[index].incrementUse();
      await _save(locations);
    }
  }

  /// 飛行記録の離陸場所から自動でよく使う場所を学習
  /// （同じ場所で3回以上飛行したら自動登録候補にする）
  static Future<List<String>> getSuggestedLocations(
      List<String> allTakeoffLocations) async {
    final count = <String, int>{};
    for (final loc in allTakeoffLocations) {
      if (loc.isNotEmpty) {
        count[loc] = (count[loc] ?? 0) + 1;
      }
    }
    // 3回以上使われた場所で、まだお気に入りに登録されていないもの
    final existing = await getAll();
    final existingAddrs = existing.map((e) => e.address).toSet();
    return count.entries
        .where((e) => e.value >= 3 && !existingAddrs.contains(e.key))
        .map((e) => e.key)
        .toList();
  }

  static Future<void> _save(List<FavoriteLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      json.encode(locations.map((l) => l.toJson()).toList()),
    );
  }
}
