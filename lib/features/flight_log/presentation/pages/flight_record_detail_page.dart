import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/flight_log_storage.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';
import '../providers/flight_log_provider.dart';
import '../widgets/location_picker_tab.dart';

/// 飛行記録 詳細表示ページ
///
/// 保存済みの飛行記録をすべてのPhase 4.5フィールド含めて表示する。
/// 遵守事項チェック、許可承認、飛行メモ、写真、PDFなど。
class FlightRecordDetailPage extends ConsumerWidget {
  final int flightId;

  const FlightRecordDetailPage({
    super.key,
    required this.flightId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightsAsync = ref.watch(flightListProvider);
    final aircraftsAsync = ref.watch(aircraftListProvider);
    final pilotsAsync = ref.watch(pilotListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('飛行記録 FLT-${flightId.toString().padLeft(4, '0')}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '複製して新規作成',
            onPressed: () => context.push('/flight-logs/flights/new?copyFrom=$flightId'),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編集',
            onPressed: () => context.push('/flight-logs/flights/$flightId/edit'),
          ),
        ],
      ),
      body: flightsAsync.when(
        data: (flights) {
          final flight = flights.where((f) => f.id == flightId).firstOrNull;
          if (flight == null) {
            return const Center(child: Text('記録が見つかりませんでした'));
          }

          // 機体名・操縦者名を解決
          var aircraftName = '機体#${flight.aircraftId}';
          var pilotName = '操縦者#${flight.pilotId}';

          aircraftsAsync.whenData((aircrafts) {
            final a = aircrafts.where((a) => a.id == flight.aircraftId).firstOrNull;
            if (a != null) aircraftName = '${a.registrationNumber} ${a.modelName ?? ""}';
          });
          pilotsAsync.whenData((pilots) {
            final p = pilots.where((p) => p.id == flight.pilotId).firstOrNull;
            if (p != null) pilotName = p.name;
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== 写真 =====
                if (flight.photoAttachments.isNotEmpty)
                  _PhotoGallery(photos: flight.photoAttachments),

                // ===== 基本情報 =====
                _SectionCard(
                  title: '基本情報',
                  icon: Icons.flight_takeoff,
                  color: Colors.blue,
                  children: [
                    _InfoRow('飛行日', flight.flightDate),
                    _InfoRow('離陸時刻', flight.takeoffTime ?? '--:--'),
                    _InfoRow('着陸時刻', flight.landingTime ?? '--:--'),
                    _InfoRow('滞空時間', flight.flightDuration != null
                        ? '${flight.flightDuration} 分' : '---'),
                    _InfoRow('操縦者', pilotName),
                    _InfoRow('無人航空機', aircraftName),
                    _InfoRow('飛行目的', flight.flightPurpose ?? '---'),
                    _InfoRow('飛行空域・方法', flight.flightArea ?? '---'),
                    _InfoRow('最大高度', flight.maxAltitude != null
                        ? '${flight.maxAltitude} m' : '---'),
                  ],
                ),

                // ===== 離陸・着陸場所 =====
                _SectionCard(
                  title: '場所',
                  icon: Icons.location_on,
                  color: Colors.green,
                  children: [
                    _InfoRow('離陸場所', flight.takeoffLocation ?? '---'),
                    if (flight.takeoffLatitude != null && flight.takeoffLongitude != null)
                      _InfoRow('座標', formatDms(flight.takeoffLatitude!, flight.takeoffLongitude!)),
                    _InfoRow('着陸場所', flight.landingLocation ?? '---'),
                  ],
                ),

                // ===== 気象・飛行メモ =====
                _SectionCard(
                  title: '飛行メモ',
                  icon: Icons.air,
                  color: Colors.teal,
                  children: [
                    _InfoRow('天候', flight.weather ?? '---'),
                    _InfoRow('風速', flight.windSpeed != null
                        ? '${flight.windSpeed} m/s' : '---'),
                    _InfoRow('気温', flight.temperature != null
                        ? '${flight.temperature} ℃' : '---'),
                    _InfoRow('バッテリー飛行前', flight.batteryBefore != null
                        ? '${flight.batteryBefore}%' : '---'),
                    _InfoRow('バッテリー飛行後', flight.batteryAfter != null
                        ? '${flight.batteryAfter}%' : '---'),
                    _InfoRow('バッテリーNo', flight.batteryNumber ?? '---'),
                    _InfoRow('飛行距離', flight.flightDistance != null
                        ? '${flight.flightDistance} m' : '---'),
                    _InfoRow('所有者承諾', flight.ownerConsent ?? '---'),
                    if (flight.notes != null && flight.notes!.isNotEmpty)
                      _InfoRow('メモ', flight.notes!),
                  ],
                ),

                // ===== 遵守事項チェック =====
                if (flight.complianceChecks.isNotEmpty)
                  _SectionCard(
                    title: '遵守事項チェック',
                    icon: Icons.checklist,
                    color: Colors.orange,
                    children: [
                      ...flight.complianceChecks.entries.map((entry) =>
                        _CheckRow(entry.key, entry.value),
                      ),
                      const SizedBox(height: 4),
                      _ComplianceSummary(checks: flight.complianceChecks),
                    ],
                  ),

                // ===== 許可承認 =====
                if (_hasPermitData(flight))
                  _SectionCard(
                    title: '許可承認',
                    icon: Icons.verified,
                    color: Colors.indigo,
                    children: [
                      _InfoRow('名称', flight.permitName ?? '---'),
                      _InfoRow('許可承認番号', flight.permitNumber ?? '---'),
                      _InfoRow('開始日付', flight.permitStartDate ?? '---'),
                      _InfoRow('終了日付', flight.permitEndDate ?? '---'),
                      _InfoRow('許可承認事項', flight.permitItems ?? '---'),
                      if (flight.permitNotes != null && flight.permitNotes!.isNotEmpty)
                        _InfoRow('備考', flight.permitNotes!),
                      // PDF添付
                      if (flight.pdfAttachments.isNotEmpty) ...[
                        const Divider(),
                        Text(
                          'PDF添付: ${flight.pdfAttachments.length}件',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        ...flight.pdfAttachments.map((pdf) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  pdf['name'] ?? 'PDF',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),

                // ===== 監督者 =====
                if (flight.supervisorNames.isNotEmpty)
                  _SectionCard(
                    title: '監督者',
                    icon: Icons.people,
                    color: Colors.purple,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: flight.supervisorNames.map((name) =>
                          Chip(
                            label: Text(name, style: const TextStyle(fontSize: 12)),
                            avatar: const Icon(Icons.person, size: 16),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ).toList(),
                      ),
                    ],
                  ),

                // ===== 経路 =====
                if (flight.notes != null && flight.notes!.isNotEmpty)
                  const _SectionCard(
                    title: '安全影響・不具合',
                    icon: Icons.shield,
                    color: Colors.teal,
                    children: [
                      _InfoRow('飛行の安全に影響のあった事項', 'なし'),
                      _InfoRow('不具合事項', 'なし'),
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

  /// 許可承認データが存在するか判定
  bool _hasPermitData(FlightRecordData flight) {
    return (flight.permitName != null && flight.permitName!.isNotEmpty) ||
        (flight.permitNumber != null && flight.permitNumber!.isNotEmpty) ||
        flight.pdfAttachments.isNotEmpty;
  }
}

/// セクションカード（共通レイアウト）
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
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 情報行（ラベル: 値）
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
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// 遵守事項チェック行
class _CheckRow extends StatelessWidget {
  final String label;
  final bool checked;

  const _CheckRow(this.label, this.checked);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: checked ? Colors.green : Colors.red[300],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: checked ? null : Colors.grey,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: checked ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              checked ? '実施済' : '未実施',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: checked ? Colors.green[700] : Colors.red[400],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 遵守事項サマリー
class _ComplianceSummary extends StatelessWidget {
  final Map<String, bool> checks;
  const _ComplianceSummary({required this.checks});

  @override
  Widget build(BuildContext context) {
    final total = checks.length;
    final done = checks.values.where((v) => v).length;
    final allDone = done == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: allDone ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            allDone ? Icons.check_circle : Icons.warning,
            size: 16,
            color: allDone ? Colors.green[700] : Colors.orange[700],
          ),
          const SizedBox(width: 6),
          Text(
            '$done / $total 項目完了',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: allDone ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// 写真ギャラリー（横スクロール）
class _PhotoGallery extends StatelessWidget {
  final List<Map<String, String>> photos;
  const _PhotoGallery({required this.photos});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  '写真 (${photos.length}枚)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final photoData = photos[index]['data'];
                  if (photoData == null) return const SizedBox.shrink();
                  try {
                    final bytes = base64Decode(photoData);
                    return GestureDetector(
                      onTap: () => _showFullScreen(context, bytes),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          bytes,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  } catch (_) {
                    return Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 全画面写真ビューア（スワイプで前後の写真に切り替え可能）
  void _showFullScreen(BuildContext context, Uint8List bytes) {
    // すべての写真をデコードしてリスト化
    final allBytes = <Uint8List>[];
    var initialIndex = 0;
    for (var i = 0; i < photos.length; i++) {
      final data = photos[i]['data'];
      if (data != null) {
        try {
          final decoded = base64Decode(data);
          if (decoded == bytes) initialIndex = allBytes.length;
          allBytes.add(decoded);
        } catch (_) {}
      }
    }
    // bytes の一致判定を改善（参照が異なる場合にindexで検索）
    for (var i = 0; i < allBytes.length; i++) {
      if (allBytes[i].length == bytes.length) {
        initialIndex = i;
        break;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          photos: allBytes,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// 全画面写真ギャラリー（スワイプ切り替え＋ピンチズーム対応）
class _FullScreenGallery extends StatefulWidget {
  final List<Uint8List> photos;
  final int initialIndex;

  const _FullScreenGallery({required this.photos, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.memory(
                widget.photos[index],
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
