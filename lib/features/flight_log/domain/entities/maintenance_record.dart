/// 様式3：整備記録エンティティ
/// 国土交通省の飛行日誌 様式3に準拠
class MaintenanceRecord {
  final int id;
  final int aircraftId;            // 整備対象機体ID
  final int maintainerId;          // 整備実施者ID（操縦者）
  final String maintenanceDate;    // 整備日（yyyy-MM-dd）
  final String maintenanceType;    // 整備種別（定期点検/修理/部品交換/その他）
  final String? description;       // 整備内容の詳細
  final String? partsReplaced;     // 交換部品
  final String? result;            // 整備結果（完了/要追加整備/不可）
  final String? nextMaintenanceDate; // 次回整備予定日
  final String? notes;             // 備考・特記事項
  final String? aircraftName;      // 機体名（表示用）
  final String? maintainerName;    // 整備者名（表示用）
  final DateTime createdAt;
  final DateTime updatedAt;

  const MaintenanceRecord({
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
    this.aircraftName,
    this.maintainerName,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  String toString() {
    return 'MaintenanceRecord(id: $id, date: $maintenanceDate, aircraft: $aircraftId, type: $maintenanceType)';
  }
}
