import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';
import '../providers/flight_log_provider.dart';

/// 整備記録（様式3）詳細表示ページ
class MaintenanceDetailPage extends ConsumerWidget {
  final int maintenanceId;

  const MaintenanceDetailPage({super.key, required this.maintenanceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenancesAsync = ref.watch(maintenanceListProvider);
    final aircraftsAsync = ref.watch(aircraftListProvider);
    final pilotsAsync = ref.watch(pilotListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('整備記録 詳細'),
        elevation: 0,
        actions: [
          // 複製ボタン
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '複製して新規作成',
            onPressed: () =>
                context.push('/flight-logs/maintenances/new?copyFrom=$maintenanceId'),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編集',
            onPressed: () =>
                context.push('/flight-logs/maintenances/$maintenanceId/edit'),
          ),
        ],
      ),
      body: maintenancesAsync.when(
        data: (maintenances) {
          final maint =
              maintenances.where((m) => m.id == maintenanceId).firstOrNull;
          if (maint == null) {
            return const Center(child: Text('記録が見つかりませんでした'));
          }

          var aircraftName = '機体#${maint.aircraftId}';
          var maintainerName = '整備者#${maint.maintainerId}';

          aircraftsAsync.whenData((aircrafts) {
            final a =
                aircrafts.where((a) => a.id == maint.aircraftId).firstOrNull;
            if (a != null) {
              aircraftName = '${a.registrationNumber} ${a.modelName ?? ""}';
            }
          });
          pilotsAsync.whenData((pilots) {
            final p =
                pilots.where((p) => p.id == maint.maintainerId).firstOrNull;
            if (p != null) maintainerName = p.name;
          });

          // 結果の色
          Color resultColor;
          switch (maint.result) {
            case '良好':
            case '正常完了':
              resultColor = Colors.green;
              break;
            case '要追加整備':
              resultColor = Colors.orange;
              break;
            case '不可':
              resultColor = Colors.red;
              break;
            default:
              resultColor = Colors.grey;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 基本情報
                _SectionCard(
                  title: '基本情報',
                  icon: Icons.build,
                  color: Colors.teal,
                  children: [
                    _InfoRow('整備日', maint.maintenanceDate),
                    _InfoRow('無人航空機', aircraftName),
                    _InfoRow('整備者', maintainerName),
                    _InfoRow('整備種別', maint.maintenanceType),
                  ],
                ),

                // 整備内容
                _SectionCard(
                  title: '整備内容',
                  icon: Icons.description,
                  color: Colors.indigo,
                  children: [
                    _InfoRow('内容', maint.description ?? '---'),
                    if (maint.partsReplaced != null &&
                        maint.partsReplaced!.isNotEmpty)
                      _InfoRow('交換部品', maint.partsReplaced!),
                  ],
                ),

                // 結果
                _SectionCard(
                  title: '結果',
                  icon: Icons.verified,
                  color: resultColor,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: resultColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: resultColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            resultColor == Colors.green
                                ? Icons.check_circle
                                : resultColor == Colors.orange
                                    ? Icons.warning
                                    : Icons.cancel,
                            color: resultColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            maint.result ?? '---',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: resultColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (maint.nextMaintenanceDate != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow('次回整備予定', maint.nextMaintenanceDate!),
                    ],
                  ],
                ),

                // 監督者
                if (maint.supervisorNames.isNotEmpty)
                  _SectionCard(
                    title: '監督者',
                    icon: Icons.people,
                    color: Colors.purple,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: maint.supervisorNames
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
                if (maint.notes != null && maint.notes!.isNotEmpty)
                  _SectionCard(
                    title: '備考',
                    icon: Icons.note,
                    color: Colors.grey,
                    children: [
                      Text(maint.notes!, style: const TextStyle(fontSize: 14)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
