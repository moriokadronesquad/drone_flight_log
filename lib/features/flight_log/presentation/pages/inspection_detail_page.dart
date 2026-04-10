import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/flight_log_storage.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';
import '../providers/flight_log_provider.dart';

/// 日常点検記録（様式2）詳細表示ページ
class InspectionDetailPage extends ConsumerWidget {
  final int inspectionId;

  const InspectionDetailPage({super.key, required this.inspectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(inspectionListProvider);
    final aircraftsAsync = ref.watch(aircraftListProvider);
    final pilotsAsync = ref.watch(pilotListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('日常点検 詳細'),
        elevation: 0,
        actions: [
          // 複製ボタン
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '複製して新規作成',
            onPressed: () =>
                context.push('/flight-logs/inspections/new?copyFrom=$inspectionId'),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編集',
            onPressed: () =>
                context.push('/flight-logs/inspections/$inspectionId/edit'),
          ),
        ],
      ),
      body: inspectionsAsync.when(
        data: (inspections) {
          final insp =
              inspections.where((i) => i.id == inspectionId).firstOrNull;
          if (insp == null) {
            return const Center(child: Text('記録が見つかりませんでした'));
          }

          var aircraftName = '機体#${insp.aircraftId}';
          var inspectorName = '点検者#${insp.inspectorId}';

          aircraftsAsync.whenData((aircrafts) {
            final a =
                aircrafts.where((a) => a.id == insp.aircraftId).firstOrNull;
            if (a != null) {
              aircraftName = '${a.registrationNumber} ${a.modelName ?? ""}';
            }
          });
          pilotsAsync.whenData((pilots) {
            final p =
                pilots.where((p) => p.id == insp.inspectorId).firstOrNull;
            if (p != null) inspectorName = p.name;
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 基本情報
                _SectionCard(
                  title: '基本情報',
                  icon: Icons.assignment,
                  color: Colors.blue,
                  children: [
                    _InfoRow('点検日', insp.inspectionDate),
                    _InfoRow('無人航空機', aircraftName),
                    _InfoRow('点検者', inspectorName),
                    _InfoRow('総合結果', insp.overallResult),
                  ],
                ),

                // 点検項目
                _SectionCard(
                  title: '点検項目',
                  icon: Icons.checklist,
                  color: Colors.orange,
                  children: [
                    _CheckItem('機体（フレーム）', insp.frameCheck),
                    _CheckItem('プロペラ', insp.propellerCheck),
                    _CheckItem('モーター', insp.motorCheck),
                    _CheckItem('バッテリー', insp.batteryCheck),
                    _CheckItem('送信機（コントローラー）', insp.controllerCheck),
                    _CheckItem('GPS', insp.gpsCheck),
                    _CheckItem('カメラ', insp.cameraCheck),
                    _CheckItem('通信系統', insp.communicationCheck),
                    const SizedBox(height: 8),
                    _ResultSummary(insp),
                  ],
                ),

                // 監督者
                if (insp.supervisorNames.isNotEmpty)
                  _SectionCard(
                    title: '監督者',
                    icon: Icons.people,
                    color: Colors.purple,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: insp.supervisorNames
                            .map((name) => Chip(
                                  label: Text(name,
                                      style: const TextStyle(fontSize: 12)),
                                  avatar:
                                      const Icon(Icons.person, size: 16),
                                ))
                            .toList(),
                      ),
                    ],
                  ),

                // 備考
                if (insp.notes != null && insp.notes!.isNotEmpty)
                  _SectionCard(
                    title: '備考',
                    icon: Icons.note,
                    color: Colors.grey,
                    children: [
                      Text(insp.notes!, style: const TextStyle(fontSize: 14)),
                    ],
                  ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}

// ===== 共通ウィジェット =====

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ]),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final bool passed;
  const _CheckItem(this.label, this.passed);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(passed ? Icons.check_circle : Icons.cancel,
              size: 18, color: passed ? Colors.green : Colors.red[300]),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style:
                      TextStyle(fontSize: 13, color: passed ? null : Colors.grey))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: passed ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(passed ? 'OK' : 'NG',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: passed ? Colors.green[700] : Colors.red[400])),
          ),
        ],
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  final DailyInspectionData insp;
  const _ResultSummary(this.insp);

  @override
  Widget build(BuildContext context) {
    final checks = [
      insp.frameCheck, insp.propellerCheck, insp.motorCheck,
      insp.batteryCheck, insp.controllerCheck, insp.gpsCheck,
      insp.cameraCheck, insp.communicationCheck,
    ];
    final passed = checks.where((c) => c).length;
    final allOk = passed == checks.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: allOk ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(allOk ? Icons.check_circle : Icons.warning,
              size: 16, color: allOk ? Colors.green[700] : Colors.orange[700]),
          const SizedBox(width: 6),
          Text('$passed / ${checks.length} 項目OK',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: allOk ? Colors.green[700] : Colors.orange[700])),
        ],
      ),
    );
  }
}
