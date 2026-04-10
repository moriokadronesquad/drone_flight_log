/// 航空機エンティティ
/// 不変なデータクラスとして実装
class Aircraft {
  final int id;
  final String registrationNumber; // 登録番号（例: JU-001）
  final String aircraftType; // マルチローター、固定翼など
  final String? manufacturer; // 製造メーカー
  final String? modelName; // モデル名
  final String? serialNumber; // シリアルナンバー
  final double? maxTakeoffWeight; // 最大離陸重量（kg）
  final int totalFlightTime; // 総飛行時間（分）
  final String? imageUrl; // 画像URL
  final DateTime createdAt; // 作成日時
  final DateTime updatedAt; // 更新日時

  /// コンストラクタ
  const Aircraft({
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

  /// copyWithメソッド（イミュータブル更新用）
  Aircraft copyWith({
    int? id,
    String? registrationNumber,
    String? aircraftType,
    String? manufacturer,
    String? modelName,
    String? serialNumber,
    double? maxTakeoffWeight,
    int? totalFlightTime,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Aircraft(
      id: id ?? this.id,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      aircraftType: aircraftType ?? this.aircraftType,
      manufacturer: manufacturer ?? this.manufacturer,
      modelName: modelName ?? this.modelName,
      serialNumber: serialNumber ?? this.serialNumber,
      maxTakeoffWeight: maxTakeoffWeight ?? this.maxTakeoffWeight,
      totalFlightTime: totalFlightTime ?? this.totalFlightTime,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Aircraft &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          registrationNumber == other.registrationNumber &&
          aircraftType == other.aircraftType &&
          manufacturer == other.manufacturer &&
          modelName == other.modelName &&
          serialNumber == other.serialNumber &&
          maxTakeoffWeight == other.maxTakeoffWeight &&
          totalFlightTime == other.totalFlightTime &&
          imageUrl == other.imageUrl &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      registrationNumber.hashCode ^
      aircraftType.hashCode ^
      manufacturer.hashCode ^
      modelName.hashCode ^
      serialNumber.hashCode ^
      maxTakeoffWeight.hashCode ^
      totalFlightTime.hashCode ^
      imageUrl.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'Aircraft(id: $id, registrationNumber: $registrationNumber, '
        'aircraftType: $aircraftType, manufacturer: $manufacturer, '
        'modelName: $modelName, serialNumber: $serialNumber, '
        'maxTakeoffWeight: $maxTakeoffWeight, totalFlightTime: $totalFlightTime, '
        'imageUrl: $imageUrl, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
