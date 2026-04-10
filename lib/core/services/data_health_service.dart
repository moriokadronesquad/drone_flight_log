import '../database/flight_log_storage.dart';
import '../database/local_storage.dart';

/// データ健全性チェックの結果を格納するクラス
class DataHealthResult {
  /// 問題なし
  final bool isHealthy;
  /// チェック項目リスト
  final List<DataHealthIssue> issues;
  /// サマリー情報
  final DataHealthSummary summary;

  const DataHealthResult({
    required this.isHealthy,
    this.issues = const [],
    required this.summary,
  });
}

/// 問題の種類
enum IssueLevel { info, warning, error }

/// 個別の問題を表すクラス
class DataHealthIssue {
  final IssueLevel level;
  final String category; // 'orphan', 'duplicate', 'inconsistent', 'missing'
  final String title;
  final String description;
  /// 修復可能かどうか
  final bool canFix;
  /// 関連データのID（修復時に使用）
  final Map<String, dynamic>? metadata;

  const DataHealthIssue({
    required this.level,
    required this.category,
    required this.title,
    required this.description,
    this.canFix = false,
    this.metadata,
  });
}

/// データ全体のサマリー
class DataHealthSummary {
  final int totalFlights;
  final int totalInspections;
  final int totalMaintenances;
  final int totalAircrafts;
  final int totalPilots;
  final int orphanFlights;
  final int orphanInspections;
  final int orphanMaintenances;
  final int duplicateCount;
  final int inconsistentCount;

  const DataHealthSummary({
    this.totalFlights = 0,
    this.totalInspections = 0,
    this.totalMaintenances = 0,
    this.totalAircrafts = 0,
    this.totalPilots = 0,
    this.orphanFlights = 0,
    this.orphanInspections = 0,
    this.orphanMaintenances = 0,
    this.duplicateCount = 0,
    this.inconsistentCount = 0,
  });
}

/// データ健全性チェックサービス
///
/// 全データを横断的にチェックして問題を検出する
class DataHealthService {
  /// 全データの健全性をチェック
  static Future<DataHealthResult> checkHealth({
    required FlightLogStorage flightStorage,
    required LocalStorage localStorage,
  }) async {
    final issues = <DataHealthIssue>[];

    // 全データ取得
    final flights = await flightStorage.getAllFlights();
    final inspections = await flightStorage.getAllInspections();
    final maintenances = await flightStorage.getAllMaintenances();
    final aircrafts = localStorage.getAllAircraftsSync();
    final pilots = localStorage.getAllPilotsSync();

    // ID セットの作成
    final aircraftIds = aircrafts.map((a) => a.id).toSet();
    final pilotIds = pilots.map((p) => p.id).toSet();

    var orphanFlights = 0;
    var orphanInspections = 0;
    var orphanMaintenances = 0;
    var duplicateCount = 0;
    var inconsistentCount = 0;

    // ── 1. 飛行記録の孤立データチェック ──
    for (final f in flights) {
      if (!aircraftIds.contains(f.aircraftId)) {
        issues.add(DataHealthIssue(
          level: IssueLevel.warning,
          category: 'orphan',
          title: '飛行記録 FLT-${f.id.toString().padLeft(4, '0')}',
          description: '存在しない機体(ID:${f.aircraftId})を参照しています',
          canFix: false,
          metadata: {'type': 'flight', 'id': f.id, 'field': 'aircraftId'},
        ));
        orphanFlights++;
      }
      if (!pilotIds.contains(f.pilotId)) {
        issues.add(DataHealthIssue(
          level: IssueLevel.warning,
          category: 'orphan',
          title: '飛行記録 FLT-${f.id.toString().padLeft(4, '0')}',
          description: '存在しない操縦者(ID:${f.pilotId})を参照しています',
          canFix: false,
          metadata: {'type': 'flight', 'id': f.id, 'field': 'pilotId'},
        ));
        orphanFlights++;
      }
    }

    // ── 2. 日常点検の孤立データチェック ──
    for (final i in inspections) {
      if (!aircraftIds.contains(i.aircraftId)) {
        issues.add(DataHealthIssue(
          level: IssueLevel.warning,
          category: 'orphan',
          title: '日常点検 #${i.id}（${i.inspectionDate}）',
          description: '存在しない機体(ID:${i.aircraftId})を参照しています',
          canFix: false,
          metadata: {'type': 'inspection', 'id': i.id, 'field': 'aircraftId'},
        ));
        orphanInspections++;
      }
      if (!pilotIds.contains(i.inspectorId)) {
        issues.add(DataHealthIssue(
          level: IssueLevel.warning,
          category: 'orphan',
          title: '日常点検 #${i.id}（${i.inspectionDate}）',
          description: '存在しない点検者(ID:${i.inspectorId})を参照しています',
          canFix: false,
          metadata: {'type': 'inspection', 'id': i.id, 'field': 'inspectorId'},
        ));
        orphanInspections++;
      }
    }

    // ── 3. 整備記録の孤立データチェック ──
    for (final m in maintenances) {
      if (!aircraftIds.contains(m.aircraftId)) {
        issues.add(DataHealthIssue(
          level: IssueLevel.warning,
          category: 'orphan',
          title: '整備記録 #${m.id}（${m.maintenanceDate}）',
          description: '存在しない機体(ID:${m.aircraftId})を参照しています',
          canFix: false,
          metadata: {'type': 'maintenance', 'id': m.id, 'field': 'aircraftId'},
        ));
        orphanMaintenances++;
      }
      if (!pilotIds.contains(m.maintainerId)) {
        issues.add(DataHealthIssue(
          level: IssueLevel.warning,
          category: 'orphan',
          title: '整備記録 #${m.id}（${m.maintenanceDate}）',
          description: '存在しない整備者(ID:${m.maintainerId})を参照しています',
          canFix: false,
          metadata: {'type': 'maintenance', 'id': m.id, 'field': 'maintainerId'},
        ));
        orphanMaintenances++;
      }
    }

    // ── 4. 飛行記録の時間整合性チェック ──
    for (final f in flights) {
      // 離陸時間 > 着陸時間のチェック
      if (f.takeoffTime != null && f.landingTime != null) {
        if (f.takeoffTime!.compareTo(f.landingTime!) > 0) {
          issues.add(DataHealthIssue(
            level: IssueLevel.error,
            category: 'inconsistent',
            title: '飛行記録 FLT-${f.id.toString().padLeft(4, '0')}',
            description: '離陸時間(${f.takeoffTime})が着陸時間(${f.landingTime})より後です',
            canFix: false,
            metadata: {'type': 'flight', 'id': f.id},
          ));
          inconsistentCount++;
        }
      }

      // 飛行時間が異常に長い（480分=8時間超え）
      if (f.flightDuration != null && f.flightDuration! > 480) {
        issues.add(DataHealthIssue(
          level: IssueLevel.warning,
          category: 'inconsistent',
          title: '飛行記録 FLT-${f.id.toString().padLeft(4, '0')}',
          description: '飛行時間(${f.flightDuration}分)が8時間を超えています',
          canFix: false,
          metadata: {'type': 'flight', 'id': f.id},
        ));
        inconsistentCount++;
      }

      // 日付が未来の場合
      final flightDate = DateTime.tryParse(f.flightDate);
      if (flightDate != null && flightDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
        issues.add(DataHealthIssue(
          level: IssueLevel.info,
          category: 'inconsistent',
          title: '飛行記録 FLT-${f.id.toString().padLeft(4, '0')}',
          description: '飛行日(${f.flightDate})が未来の日付です',
          canFix: false,
          metadata: {'type': 'flight', 'id': f.id},
        ));
        inconsistentCount++;
      }
    }

    // ── 5. 重複データチェック ──
    // 同一日・同一機体・同一時間の飛行記録
    final flightKeys = <String>{};
    for (final f in flights) {
      final key = '${f.flightDate}_${f.aircraftId}_${f.takeoffTime}';
      if (flightKeys.contains(key)) {
        issues.add(DataHealthIssue(
          level: IssueLevel.info,
          category: 'duplicate',
          title: '飛行記録 FLT-${f.id.toString().padLeft(4, '0')}',
          description: '同日・同機体・同時刻の飛行記録が重複しています（${f.flightDate}）',
          canFix: false,
          metadata: {'type': 'flight', 'id': f.id},
        ));
        duplicateCount++;
      }
      flightKeys.add(key);
    }

    // 同一日・同一機体の点検記録
    final inspectionKeys = <String>{};
    for (final i in inspections) {
      final key = '${i.inspectionDate}_${i.aircraftId}';
      if (inspectionKeys.contains(key)) {
        issues.add(DataHealthIssue(
          level: IssueLevel.info,
          category: 'duplicate',
          title: '日常点検 #${i.id}',
          description: '同日・同機体の点検記録が重複しています（${i.inspectionDate}）',
          canFix: false,
          metadata: {'type': 'inspection', 'id': i.id},
        ));
        duplicateCount++;
      }
      inspectionKeys.add(key);
    }

    // ── 6. 使用されていない機体・操縦者チェック ──
    final usedAircraftIds = <int>{};
    final usedPilotIds = <int>{};
    for (final f in flights) {
      usedAircraftIds.add(f.aircraftId);
      usedPilotIds.add(f.pilotId);
    }
    for (final i in inspections) {
      usedAircraftIds.add(i.aircraftId);
      usedPilotIds.add(i.inspectorId);
    }
    for (final m in maintenances) {
      usedAircraftIds.add(m.aircraftId);
      usedPilotIds.add(m.maintainerId);
    }

    for (final ac in aircrafts) {
      if (!usedAircraftIds.contains(ac.id)) {
        issues.add(DataHealthIssue(
          level: IssueLevel.info,
          category: 'missing',
          title: '機体: ${ac.registrationNumber}',
          description: 'この機体はどの記録にも使用されていません',
          canFix: false,
        ));
      }
    }

    for (final p in pilots) {
      if (!usedPilotIds.contains(p.id)) {
        issues.add(DataHealthIssue(
          level: IssueLevel.info,
          category: 'missing',
          title: '操縦者: ${p.name}',
          description: 'この操縦者はどの記録にも使用されていません',
          canFix: false,
        ));
      }
    }

    final summary = DataHealthSummary(
      totalFlights: flights.length,
      totalInspections: inspections.length,
      totalMaintenances: maintenances.length,
      totalAircrafts: aircrafts.length,
      totalPilots: pilots.length,
      orphanFlights: orphanFlights,
      orphanInspections: orphanInspections,
      orphanMaintenances: orphanMaintenances,
      duplicateCount: duplicateCount,
      inconsistentCount: inconsistentCount,
    );

    // error > warning > info の順にソート
    issues.sort((a, b) => a.level.index.compareTo(b.level.index));

    return DataHealthResult(
      isHealthy: issues.where((i) => i.level == IssueLevel.error || i.level == IssueLevel.warning).isEmpty,
      issues: issues,
      summary: summary,
    );
  }
}
