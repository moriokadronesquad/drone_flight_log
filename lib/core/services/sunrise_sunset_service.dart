import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// 日の出・日の入りデータ
class SunriseSunsetData {
  final String sunrise;
  final String sunset;
  final String civilTwilightBegin;
  final String civilTwilightEnd;
  final String date;
  final double latitude;
  final double longitude;

  SunriseSunsetData({
    required this.sunrise,
    required this.sunset,
    required this.civilTwilightBegin,
    required this.civilTwilightEnd,
    required this.date,
    required this.latitude,
    required this.longitude,
  });
}

/// 日の出・日の入りAPIサービス
///
/// sunrise-sunset.org API（無料・キー不要）を使用して
/// 指定した緯度経度・日付の日の出/日の入り時刻を取得する。
/// 航空法では日出前・日没後の飛行に制限があるため重要な参考情報。
class SunriseSunsetService {
  /// APIベースURL
  static const _baseUrl = 'https://api.sunrise-sunset.org/json';

  /// デフォルト座標（東京）
  static const _defaultLat = 35.6762;
  static const _defaultLng = 139.6503;

  /// 日の出・日の入り情報を取得
  ///
  /// [date] 取得する日付（yyyy-MM-dd形式）
  /// [latitude] 緯度（省略時は東京）
  /// [longitude] 経度（省略時は東京）
  static Future<SunriseSunsetData?> getSunriseSunset({
    required String date,
    double? latitude,
    double? longitude,
  }) async {
    final lat = latitude ?? _defaultLat;
    final lng = longitude ?? _defaultLng;

    try {
      final uri = Uri.parse(
        '$_baseUrl?lat=$lat&lng=$lng&date=$date&formatted=0',
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        debugPrint('SunriseSunsetService: HTTP ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String?;

      if (status != 'OK') {
        debugPrint('SunriseSunsetService: API status=$status');
        return null;
      }

      final results = json['results'] as Map<String, dynamic>;

      // UTC → JST に変換
      final sunrise = _utcToJst(results['sunrise'] as String);
      final sunset = _utcToJst(results['sunset'] as String);
      final twilightBegin = _utcToJst(results['civil_twilight_begin'] as String);
      final twilightEnd = _utcToJst(results['civil_twilight_end'] as String);

      return SunriseSunsetData(
        sunrise: sunrise,
        sunset: sunset,
        civilTwilightBegin: twilightBegin,
        civilTwilightEnd: twilightEnd,
        date: date,
        latitude: lat,
        longitude: lng,
      );
    } catch (e) {
      debugPrint('SunriseSunsetService: エラー: $e');
      return null;
    }
  }

  /// UTC ISO8601文字列を日本時間（HH:mm形式）に変換
  static String _utcToJst(String utcString) {
    try {
      final utcTime = DateTime.parse(utcString);
      final jstTime = utcTime.add(const Duration(hours: 9));
      return DateFormat('HH:mm').format(jstTime);
    } catch (e) {
      return '-';
    }
  }
}
