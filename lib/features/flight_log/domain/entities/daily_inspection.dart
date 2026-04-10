/// 様式2：日常点検記録エンティティ
/// 国土交通省の飛行日誌 様式2に準拠
class DailyInspection {
  final int id;
  final int aircraftId;           // 点検対象機体ID
  final int inspectorId;          // 点検者ID（操縦者）
  final String inspectionDate;    // 点検日（yyyy-MM-dd）
  final bool frameCheck;          // 機体（フレーム）の確認
  final bool propellerCheck;      // プロペラの確認
  final bool motorCheck;          // モーターの確認
  final bool batteryCheck;        // バッテリーの確認
  final bool controllerCheck;     // 送信機（コントローラー）の確認
  final bool gpsCheck;            // GPS/センサーの確認
  final bool cameraCheck;         // カメラ/ペイロードの確認
  final bool communicationCheck;  // 通信系統の確認
  final String overallResult;     // 総合判定（合格/不合格/要整備）
  final String? notes;            // 備考・特記事項
  final String? aircraftName;     // 機体名（表示用）
  final String? inspectorName;    // 点検者名（表示用）
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyInspection({
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
    this.aircraftName,
    this.inspectorName,
    required this.createdAt,
    required this.updatedAt,
  });

  /// すべての点検項目が合格かどうか
  bool get allChecked =>
      frameCheck &&
      propellerCheck &&
      motorCheck &&
      batteryCheck &&
      controllerCheck &&
      gpsCheck &&
      cameraCheck &&
      communicationCheck;

  @override
  String toString() {
    return 'DailyInspection(id: $id, date: $inspectionDate, aircraft: $aircraftId, result: $overallResult)';
  }
}
