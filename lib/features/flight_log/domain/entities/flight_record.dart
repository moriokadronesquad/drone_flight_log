/// 様式1：飛行実績記録エンティティ
/// 国土交通省の飛行日誌 様式1に準拠
class FlightRecord {
  final int id;
  final int aircraftId;         // 使用機体ID
  final int pilotId;            // 操縦者ID
  final String flightDate;      // 飛行日（yyyy-MM-dd）
  final String? takeoffTime;    // 離陸時刻（HH:mm）
  final String? landingTime;    // 着陸時刻（HH:mm）
  final int? flightDuration;    // 飛行時間（分）
  final String? takeoffLocation; // 離陸場所
  final String? landingLocation; // 着陸場所
  final String? flightPurpose;  // 飛行目的
  final String? flightArea;     // 飛行空域（DID, 目視外, 夜間 など）
  final String? maxAltitude;    // 最大高度
  final String? weather;        // 天候
  final String? windSpeed;      // 風速
  final String? temperature;    // 気温
  final String? notes;          // 備考・特記事項
  final String? aircraftName;   // 機体名（表示用）
  final String? pilotName;      // 操縦者名（表示用）
  final DateTime createdAt;
  final DateTime updatedAt;

  const FlightRecord({
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
    this.aircraftName,
    this.pilotName,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  String toString() {
    return 'FlightRecord(id: $id, date: $flightDate, aircraft: $aircraftId, pilot: $pilotId)';
  }
}
