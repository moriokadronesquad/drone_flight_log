import 'dart:convert';
import 'package:http/http.dart' as http;

/// Google Apps Script Web APIを介してスプレッドシートと連携するサービス
///
/// FlutterアプリからGASのdoGet/doPostを呼び出し、
/// スプレッドシートのデータを読み書きする
class SpreadsheetApiService {
  /// GAS Web APIのURL
  static const String _baseUrl =
      'https://script.google.com/macros/s/AKfycbxgoZIbdJ12dv-bkd_ld17VbbDNVACVzxqRiZhOslPl_ACTO6S4P_f9IKFO60ZqSsPQyg/exec';

  /// 接続状態を確認する
  static Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=getAircrafts'),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── データ取得（GET） ───

  /// 全データを一括取得する
  static Future<Map<String, dynamic>> getAllData() async {
    return await _get('getAll');
  }

  /// 機体マスタを取得する
  static Future<List<Map<String, dynamic>>> getAircrafts() async {
    final result = await _get('getAircrafts');
    return _toList(result);
  }

  /// 操縦者マスタを取得する
  static Future<List<Map<String, dynamic>>> getPilots() async {
    final result = await _get('getPilots');
    return _toList(result);
  }

  /// 飛行記録を取得する
  static Future<List<Map<String, dynamic>>> getFlights() async {
    final result = await _get('getFlights');
    return _toList(result);
  }

  /// 日常点検を取得する
  static Future<List<Map<String, dynamic>>> getInspections() async {
    final result = await _get('getInspections');
    return _toList(result);
  }

  /// 整備記録を取得する
  static Future<List<Map<String, dynamic>>> getMaintenance() async {
    final result = await _get('getMaintenance');
    return _toList(result);
  }

  // ─── データ書き込み（POST） ───

  /// 飛行記録を追加する
  static Future<Map<String, dynamic>> addFlight(Map<String, dynamic> data) async {
    return _post('addFlight', data);
  }

  /// 日常点検を追加する
  static Future<Map<String, dynamic>> addInspection(Map<String, dynamic> data) async {
    return _post('addInspection', data);
  }

  /// 整備記録を追加する
  static Future<Map<String, dynamic>> addMaintenance(Map<String, dynamic> data) async {
    return _post('addMaintenance', data);
  }

  /// 機体を追加する
  static Future<Map<String, dynamic>> addAircraft(Map<String, dynamic> data) async {
    return _post('addAircraft', data);
  }

  /// 操縦者を追加する
  static Future<Map<String, dynamic>> addPilot(Map<String, dynamic> data) async {
    return _post('addPilot', data);
  }

  // ─── 内部メソッド ───

  /// GETリクエストを送信する
  static Future<dynamic> _get(String action) async {
    try {
      final uri = Uri.parse('$_baseUrl?action=$action');
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('APIエラー: ステータスコード ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('データ取得に失敗しました: $e');
    }
  }

  /// POSTリクエストを送信する
  static Future<Map<String, dynamic>> _post(String action, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse(_baseUrl);
      final body = json.encode({
        'action': action,
        'data': data,
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('APIエラー: ステータスコード ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('データ送信に失敗しました: $e');
    }
  }

  /// APIレスポンスをList<Map>に変換する
  static List<Map<String, dynamic>> _toList(dynamic data) {
    if (data is List) {
      return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }
}
