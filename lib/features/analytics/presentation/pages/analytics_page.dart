import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../../core/database/local_storage.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/download_helper.dart';
import '../../../../core/services/flight_summary_service.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';
import '../../../flight_log/presentation/providers/flight_log_provider.dart';
import '../providers/analytics_provider.dart';

/// 飛行データ分析ページ
/// Phase 3: 統計情報・グラフを表示
/// Phase 8: 月次レポートPDF出力機能追加
class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(flightStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('飛行データ分析'),
        elevation: 0,
        actions: [
          // 月次レポートPDF出力
          statsAsync.maybeWhen(
            data: (stats) => stats.totalFlights > 0
                ? IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    tooltip: '月次レポートPDF出力',
                    onPressed: () => _showMonthlyReportDialog(context),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          // 分析データCSVエクスポート
          statsAsync.maybeWhen(
            data: (stats) => stats.totalFlights > 0
                ? IconButton(
                    icon: const Icon(Icons.file_download),
                    tooltip: '分析データをCSVエクスポート',
                    onPressed: () => _exportAnalyticsCsv(context, stats),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          // テキストサマリーをコピー
          statsAsync.maybeWhen(
            data: (stats) => stats.totalFlights > 0
                ? IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'サマリーをコピー',
                    onPressed: () => _copyFlightSummary(context),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) => _buildContent(context, stats),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }

  /// 月次レポート期間選択ダイアログ
  Future<void> _showMonthlyReportDialog(BuildContext context) async {
    var startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    var endDate = DateTime.now();

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('月次レポート生成'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('レポートの期間を選択してください:'),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('開始日'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(startDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => startDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('終了日'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(endDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => endDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // クイック選択ボタン
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('今月'),
                        onPressed: () {
                          final now = DateTime.now();
                          setDialogState(() {
                            startDate = DateTime(now.year, now.month, 1);
                            endDate = now;
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('先月'),
                        onPressed: () {
                          final now = DateTime.now();
                          final lastMonth = DateTime(now.year, now.month - 1, 1);
                          setDialogState(() {
                            startDate = lastMonth;
                            endDate = DateTime(now.year, now.month, 0);
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('過去3ヶ月'),
                        onPressed: () {
                          final now = DateTime.now();
                          setDialogState(() {
                            startDate = DateTime(now.year, now.month - 3, 1);
                            endDate = now;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('PDF生成'),
                  onPressed: () => Navigator.pop(ctx, {
                    'start': startDate,
                    'end': endDate,
                  }),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    await _generateMonthlyReport(result['start']!, result['end']!);
  }

  /// 月次レポートPDFを生成して表示
  Future<void> _generateMonthlyReport(DateTime startDate, DateTime endDate) async {
    try {
      final flights = await ref.read(flightListProvider.future);
      final localStorage = await ref.read(localStorageProvider.future);

      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);

      // 期間内の飛行記録を抽出
      final filteredFlights = flights.where((f) {
        return f.flightDate.compareTo(startStr) >= 0 &&
               f.flightDate.compareTo(endStr) <= 0;
      }).toList()
        ..sort((a, b) => a.flightDate.compareTo(b.flightDate));

      if (filteredFlights.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('指定期間の飛行記録がありません'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 名前マップ作成
      final aircraftNames = <int, String>{};
      for (final a in localStorage.getAllAircraftsSync()) {
        aircraftNames[a.id] = '${a.registrationNumber} ${a.modelName ?? ""}';
      }
      final pilotNames = <int, String>{};
      for (final p in localStorage.getAllPilotsSync()) {
        pilotNames[p.id] = p.name;
      }

      final pdfBytes = await PdfService.generateMonthlyReportPdf(
        flights: filteredFlights,
        startDate: startStr,
        endDate: endStr,
        aircraftNames: aircraftNames,
        pilotNames: pilotNames,
      );

      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '月次飛行レポート_${startStr}_$endStr',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('レポート生成に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildContent(BuildContext context, FlightStatistics stats) {
    if (stats.totalFlights == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '飛行データがありません',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '飛行記録を追加すると、ここに分析データが表示されます',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // サマリーカード
          _buildSummaryCards(context, stats),
          const SizedBox(height: 24),

          // 月別飛行回数（棒グラフ）
          if (stats.flightsByMonth.isNotEmpty) ...[
            const _SectionTitle(title: '月別飛行回数'),
            const SizedBox(height: 8),
            _MonthlyBarChart(data: stats.flightsByMonth),
            const SizedBox(height: 24),
          ],

          // 機体別飛行回数（円グラフ）
          if (stats.flightsByAircraft.isNotEmpty) ...[
            const _SectionTitle(title: '機体別飛行回数'),
            const SizedBox(height: 8),
            _PieChartCard(data: stats.flightsByAircraft),
            const SizedBox(height: 24),
          ],

          // 操縦者別飛行回数（円グラフ）
          if (stats.flightsByPilot.isNotEmpty) ...[
            const _SectionTitle(title: '操縦者別飛行回数'),
            const SizedBox(height: 8),
            _PieChartCard(data: stats.flightsByPilot),
            const SizedBox(height: 24),
          ],

          // 飛行目的別（横棒グラフ）
          if (stats.flightsByPurpose.isNotEmpty) ...[
            const _SectionTitle(title: '飛行目的別'),
            const SizedBox(height: 8),
            _HorizontalBarChart(data: stats.flightsByPurpose),
            const SizedBox(height: 24),
          ],

          // 飛行空域別（横棒グラフ）
          if (stats.flightsByArea.isNotEmpty) ...[
            const _SectionTitle(title: '飛行空域・方法別'),
            const SizedBox(height: 8),
            _HorizontalBarChart(data: stats.flightsByArea),
            const SizedBox(height: 24),
          ],

          // 天候別（横棒グラフ）
          if (stats.flightsByWeather.isNotEmpty) ...[
            const _SectionTitle(title: '天候別飛行回数'),
            const SizedBox(height: 8),
            _HorizontalBarChart(data: stats.flightsByWeather),
            const SizedBox(height: 24),
          ],

          // 最近の飛行
          if (stats.recentFlights.isNotEmpty) ...[
            const _SectionTitle(title: '最近の飛行記録'),
            const SizedBox(height: 8),
            ...stats.recentFlights.map((f) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.flight_takeoff,
                        color: Colors.orange),
                    title: Text(f.flightDate),
                    subtitle: Text(
                      '${f.flightPurpose ?? "目的未設定"}'
                      '${f.flightDuration != null ? " / ${f.flightDuration}分" : ""}',
                    ),
                    trailing: Text(
                      f.takeoffLocation ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 分析データをCSV形式でエクスポート
  /// 飛行サマリーをクリップボードにコピー
  Future<void> _copyFlightSummary(BuildContext context) async {
    try {
      final flightsAsync = ref.read(flightListProvider);
      final flights = flightsAsync.valueOrNull ?? [];

      if (flights.isEmpty) return;

      // 名前マップ構築
      final aircraftNames = <int, String>{};
      final pilotNames = <int, String>{};
      final aircraftsAsync = ref.read(aircraftListProvider);
      aircraftsAsync.whenData((list) {
        for (final a in list) {
          aircraftNames[a.id] = a.registrationNumber;
        }
      });
      final pilotsAsync = ref.read(pilotListProvider);
      pilotsAsync.whenData((list) {
        for (final p in list) {
          pilotNames[p.id] = p.name;
        }
      });

      // 全期間のサマリーを生成
      final sortedFlights = [...flights]..sort((a, b) => a.flightDate.compareTo(b.flightDate));
      final startDate = sortedFlights.first.flightDate;
      final endDate = sortedFlights.last.flightDate;

      final summary = FlightSummaryService.generatePeriodSummary(
        flights: flights,
        startDate: startDate,
        endDate: endDate,
        aircraftNames: aircraftNames,
        pilotNames: pilotNames,
      );

      await Clipboard.setData(ClipboardData(text: summary));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('飛行サマリーをクリップボードにコピーしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('コピーに失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _exportAnalyticsCsv(BuildContext context, FlightStatistics stats) {
    try {
      final buf = StringBuffer();

      // サマリーセクション
      buf.writeln('=== 飛行データ分析レポート ===');
      buf.writeln('出力日,${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      buf.writeln('');
      buf.writeln('項目,値');
      buf.writeln('総飛行回数,${stats.totalFlights}');
      buf.writeln('総飛行時間(分),${stats.totalFlightMinutes}');
      buf.writeln('登録機体数,${stats.totalAircrafts}');
      buf.writeln('登録操縦者数,${stats.totalPilots}');
      buf.writeln('点検記録数,${stats.totalInspections}');
      buf.writeln('整備記録数,${stats.totalMaintenances}');
      buf.writeln('');

      // 月別飛行回数
      if (stats.flightsByMonth.isNotEmpty) {
        buf.writeln('=== 月別飛行回数 ===');
        buf.writeln('月,回数');
        for (final e in stats.flightsByMonth.entries) {
          buf.writeln('${e.key},${e.value}');
        }
        buf.writeln('');
      }

      // 機体別飛行回数
      if (stats.flightsByAircraft.isNotEmpty) {
        buf.writeln('=== 機体別飛行回数 ===');
        buf.writeln('機体,回数');
        for (final e in stats.flightsByAircraft.entries) {
          buf.writeln('${e.key},${e.value}');
        }
        buf.writeln('');
      }

      // 操縦者別飛行回数
      if (stats.flightsByPilot.isNotEmpty) {
        buf.writeln('=== 操縦者別飛行回数 ===');
        buf.writeln('操縦者,回数');
        for (final e in stats.flightsByPilot.entries) {
          buf.writeln('${e.key},${e.value}');
        }
        buf.writeln('');
      }

      // 飛行目的別
      if (stats.flightsByPurpose.isNotEmpty) {
        buf.writeln('=== 飛行目的別 ===');
        buf.writeln('目的,回数');
        for (final e in stats.flightsByPurpose.entries) {
          buf.writeln('${e.key},${e.value}');
        }
        buf.writeln('');
      }

      // 空域別
      if (stats.flightsByArea.isNotEmpty) {
        buf.writeln('=== 飛行空域別 ===');
        buf.writeln('空域,回数');
        for (final e in stats.flightsByArea.entries) {
          buf.writeln('${e.key},${e.value}');
        }
        buf.writeln('');
      }

      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      downloadCsvFile(buf.toString(), '飛行分析レポート_$now.csv');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分析レポートをエクスポートしました'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エクスポートに失敗しました: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// サマリーカード群
  Widget _buildSummaryCards(BuildContext context, FlightStatistics stats) {
    final hours = stats.totalFlightMinutes ~/ 60;
    final minutes = stats.totalFlightMinutes % 60;
    final timeText = hours > 0 ? '$hours時間$minutes分' : '$minutes分';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: '総飛行回数',
                value: '${stats.totalFlights}',
                unit: '回',
                icon: Icons.flight,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: '総飛行時間',
                value: timeText,
                unit: '',
                icon: Icons.timer,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: '登録機体',
                value: '${stats.totalAircrafts}',
                unit: '機',
                icon: Icons.airplanemode_active,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: '登録操縦者',
                value: '${stats.totalPilots}',
                unit: '人',
                icon: Icons.person,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: '日常点検',
                value: '${stats.totalInspections}',
                unit: '件',
                icon: Icons.checklist,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: '整備記録',
                value: '${stats.totalMaintenances}',
                unit: '件',
                icon: Icons.build,
                color: Colors.brown,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// セクションタイトル
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
    );
  }
}

/// サマリーカード
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(unit,
                        style: TextStyle(color: color, fontSize: 14)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 月別飛行回数の棒グラフ
class _MonthlyBarChart extends StatelessWidget {
  final Map<String, int> data;
  const _MonthlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final maxVal = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
        child: SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxVal + 1).toDouble(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${entries[groupIndex].key}\n${rod.toY.toInt()}回',
                      const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      // "2025-01" → "1月"
                      final month = entries[idx].key;
                      final m = month.length >= 7
                          ? int.tryParse(month.substring(5, 7)) ?? 0
                          : 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$m月',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value % 1 != 0) return const SizedBox.shrink();
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 11),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
              ),
              barGroups: entries.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.value.toDouble(),
                      color: Colors.blue.shade400,
                      width: 24,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// 円グラフカード
class _PieChartCard extends StatelessWidget {
  final Map<String, int> data;
  const _PieChartCard({required this.data});

  static const _colors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: entries.asMap().entries.map((entry) {
                    final color = _colors[entry.key % _colors.length];
                    final pct = (entry.value.value / total * 100).round();
                    return PieChartSectionData(
                      value: entry.value.value.toDouble(),
                      color: color,
                      title: '$pct%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      radius: 60,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 凡例
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: entries.asMap().entries.map((entry) {
                final color = _colors[entry.key % _colors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.value.key} (${entry.value.value})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 横棒グラフ（カテゴリ別集計）
class _HorizontalBarChart extends StatelessWidget {
  final Map<String, int> data;
  const _HorizontalBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = entries.isNotEmpty ? entries.first.value : 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: entries.map((entry) {
            final ratio = entry.value / maxVal;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade400,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '${entry.value}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
