import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/database/flight_log_storage.dart';
import '../../../../core/services/csv_service.dart';
import '../../../../core/services/download_helper.dart';
import '../../../../core/services/excel_import_service.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';
import '../providers/flight_log_provider.dart';
import '../widgets/flight_filter_dialog.dart';
import '../widgets/inspection_filter_dialog.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/help_tooltip.dart';

/// 飛行記録メインページ
/// 3つのタブ（様式1〜3）で飛行記録を表示
class FlightLogPage extends ConsumerStatefulWidget {
  const FlightLogPage({super.key});

  @override
  ConsumerState<FlightLogPage> createState() => _FlightLogPageState();
}

class _FlightLogPageState extends ConsumerState<FlightLogPage> {
  // フィルター状態（様式1用）
  int? _filterAircraftId;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _isFiltered = false;

  // 検索・ソート状態（様式1用）
  String _searchQuery = '';
  String _sortKey = 'date_desc'; // date_desc, date_asc, duration_desc, location
  final _searchController = TextEditingController();

  // バッチ選択モード
  bool _batchMode = false;
  final Set<int> _selectedFlightIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: _batchMode
              ? Text('${_selectedFlightIds.length}件選択中')
              : const Text('飛行記録'),
          elevation: 0,
          leading: _batchMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _batchMode = false;
                    _selectedFlightIds.clear();
                  }),
                )
              : null,
          actions: _batchMode
              ? [
                  // 全選択
                  IconButton(
                    icon: const Icon(Icons.select_all),
                    tooltip: '全選択',
                    onPressed: () => _selectAllFlights(),
                  ),
                  // 選択したものをCSVエクスポート
                  IconButton(
                    icon: const Icon(Icons.file_download),
                    tooltip: '選択をCSVエクスポート',
                    onPressed: _selectedFlightIds.isEmpty
                        ? null
                        : () => _exportSelectedFlightsCsv(context),
                  ),
                  // 選択したものを削除
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: '選択を削除',
                    onPressed: _selectedFlightIds.isEmpty
                        ? null
                        : () => _deleteSelectedFlights(context),
                  ),
                ]
              : [
                  // ヘルプ
                  const HelpTooltipButton(
                    title: '飛行記録の使い方',
                    tips: [
                      '＋ボタンで飛行記録・点検・整備を新規作成できます。',
                      'タブで様式1（飛行記録）、様式2（点検）、様式3（整備）を切り替えられます。',
                      'フィルターアイコンで期間や機体で絞り込み、PDFも出力できます。',
                      '一括操作ボタンで複数の記録をまとめてCSVエクスポート・削除できます。',
                      'インポートボタンからCSV/Excelファイルを読み込めます。',
                    ],
                  ),
                  // バッチ選択モード
                  IconButton(
                    icon: const Icon(Icons.checklist_rtl),
                    tooltip: '一括操作',
                    onPressed: () => setState(() => _batchMode = true),
                  ),
                  // フィルターボタン
                  IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: _isFiltered ? Colors.amber : null,
                    ),
                    tooltip: '絞り込み・PDF出力',
                    onPressed: () => _showFilterDialog(context),
                  ),
                  // インポートメニュー（CSV/Excel）
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.file_upload),
                    tooltip: 'インポート',
                    onSelected: (value) {
                      if (value == 'csv') {
                        _importFlightsCsv(context);
                      } else if (value == 'excel') {
                        _importFlightsExcel(context);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'csv',
                        child: Row(
                          children: [
                            Icon(Icons.description, size: 20),
                            SizedBox(width: 8),
                            Text('CSVインポート'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'excel',
                        child: Row(
                          children: [
                            Icon(Icons.table_chart, size: 20, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Excelインポート'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 飛行記録CSVエクスポート
                  IconButton(
                    icon: const Icon(Icons.file_download),
                    tooltip: '飛行記録をCSVエクスポート',
                    onPressed: () => _exportFlightsCsv(context),
                  ),
                  // 分析ページへ
                  IconButton(
                    icon: const Icon(Icons.analytics),
                    tooltip: '飛行分析',
                    onPressed: () => context.push('/analytics'),
                  ),
                ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '様式1\n飛行実績', icon: Icon(Icons.flight_takeoff)),
              Tab(text: '様式2\n日常点検', icon: Icon(Icons.checklist)),
              Tab(text: '様式3\n整備記録', icon: Icon(Icons.build)),
            ],
            labelStyle: TextStyle(fontSize: 11),
          ),
        ),
        body: TabBarView(
          children: [
            _FlightRecordTab(
              filterAircraftId: _filterAircraftId,
              filterStartDate: _filterStartDate,
              filterEndDate: _filterEndDate,
              isFiltered: _isFiltered,
              searchQuery: _searchQuery,
              sortKey: _sortKey,
              batchMode: _batchMode,
              selectedIds: _selectedFlightIds,
              onSelectionChanged: (id, selected) {
                setState(() {
                  if (selected) {
                    _selectedFlightIds.add(id);
                  } else {
                    _selectedFlightIds.remove(id);
                  }
                });
              },
              onClearFilter: () {
                setState(() {
                  _filterAircraftId = null;
                  _filterStartDate = null;
                  _filterEndDate = null;
                  _isFiltered = false;
                });
              },
              searchController: _searchController,
              onSearchChanged: (q) => setState(() => _searchQuery = q),
              onSortChanged: (s) => setState(() => _sortKey = s),
            ),
            const _DailyInspectionTab(),
            const _MaintenanceRecordTab(),
          ],
        ),
      ),
    );
  }

  /// フィルターダイアログを表示
  Future<void> _showFilterDialog(BuildContext context) async {
    final result = await showDialog<FlightFilterResult>(
      context: context,
      builder: (ctx) => FlightFilterDialog(
        initialAircraftId: _filterAircraftId,
        initialStartDate: _filterStartDate,
        initialEndDate: _filterEndDate,
      ),
    );

    if (result == null) return;

    if (result.exportPdf) {
      // PDF出力
      await _exportPdf(
        context,
        aircraftId: result.aircraftId,
        startDate: result.startDate,
        endDate: result.endDate,
      );
    }

    // フィルター適用
    setState(() {
      _filterAircraftId = result.aircraftId;
      _filterStartDate = result.startDate;
      _filterEndDate = result.endDate;
      _isFiltered = result.aircraftId != null ||
          result.startDate != null ||
          result.endDate != null;
    });
  }

  /// 国交省様式1 PDF出力
  Future<void> _exportPdf(
    BuildContext context, {
    int? aircraftId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final storage = await ref.read(flightLogStorageProvider.future);
      var flights = await storage.getAllFlights();

      // フィルタリング
      if (aircraftId != null) {
        flights = flights.where((f) => f.aircraftId == aircraftId).toList();
      }
      if (startDate != null) {
        final start = DateFormat('yyyy-MM-dd').format(startDate);
        flights = flights.where((f) => f.flightDate.compareTo(start) >= 0).toList();
      }
      if (endDate != null) {
        final end = DateFormat('yyyy-MM-dd').format(endDate);
        flights = flights.where((f) => f.flightDate.compareTo(end) <= 0).toList();
      }

      if (flights.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('条件に一致する飛行記録がありません'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 日付昇順にソート
      flights.sort((a, b) => a.flightDate.compareTo(b.flightDate));

      // 機体名・パイロット名の取得
      String? aircraftName;
      Map<String, String>? aircraftInfo;
      final aircraftsAsync = ref.read(aircraftListProvider);
      aircraftsAsync.whenData((list) {
        if (aircraftId != null) {
          final ac = list.where((a) => a.id == aircraftId).toList();
          if (ac.isNotEmpty) {
            aircraftName = '${ac.first.registrationNumber} - ${ac.first.modelName}';
            aircraftInfo = {
              'manufacturer': ac.first.manufacturer ?? '',
              'weight': ac.first.maxTakeoffWeight?.toString() ?? '',
            };
          }
        }
      });

      final pilotMap = <int, String>{};
      final pilotsAsync = ref.read(pilotListProvider);
      pilotsAsync.whenData((list) {
        for (final p in list) {
          pilotMap[p.id] = p.name;
        }
      });

      // PDF生成
      final pdfBytes = await PdfService.generateFlightRecordPdf(
        flights: flights,
        aircraftName: aircraftName,
        aircraftInfo: aircraftInfo,
        pilotNames: pilotMap,
      );

      // 印刷/共有ダイアログ表示
      if (context.mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: '飛行実績記録_様式1',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF出力に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 飛行記録をCSVインポート
  Future<void> _importFlightsCsv(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ファイルの読み込みに失敗しました'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // BOM付きUTF-8を処理
      var csvString = utf8.decode(fileBytes, allowMalformed: true);
      if (csvString.startsWith('\uFEFF')) {
        csvString = csvString.substring(1);
      }

      final records = CsvService.parseFlightCsv(csvString);

      if (records.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('インポートできる飛行記録がありませんでした'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // 確認ダイアログ
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('CSVインポート'),
          content: Text('${records.length}件の飛行記録をインポートします。\nよろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('インポート'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      final count = await ref.read(flightFormProvider.notifier).importFlights(records);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count件の飛行記録をインポートしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('インポートに失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 飛行記録をExcel(.xlsx)からインポート
  Future<void> _importFlightsExcel(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ファイルの読み込みに失敗しました'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final importResult = ExcelImportService.importFlights(bytes);

      if (importResult.flights.isEmpty) {
        if (context.mounted) {
          final errMsg = importResult.errors.isNotEmpty
              ? importResult.errors.first
              : 'インポート可能な飛行記録が見つかりません';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // 確認ダイアログ
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excelインポート確認'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${importResult.successCount}件の飛行記録が見つかりました。'),
              if (importResult.hasErrors) ...[
                const SizedBox(height: 8),
                Text(
                  '${importResult.errors.length}件の警告:',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
                ...importResult.errors.take(3).map((e) => Text(e, style: const TextStyle(fontSize: 11))),
              ],
              const SizedBox(height: 12),
              const Text('インポートしますか？', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('インポート'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // インポート実行
      final storage = await ref.read(flightLogStorageProvider.future);
      var imported = 0;

      for (final record in importResult.flights) {
        await storage.createFlight(
          aircraftId: 1, // デフォルト機体ID（後で編集可能）
          pilotId: 1,    // デフォルト操縦者ID
          flightDate: record['flightDate'] ?? '',
          takeoffTime: record['takeoffTime']?.isNotEmpty == true ? record['takeoffTime'] : null,
          landingTime: record['landingTime']?.isNotEmpty == true ? record['landingTime'] : null,
          flightDuration: int.tryParse(record['flightDuration'] ?? ''),
          takeoffLocation: record['flightLocation']?.isNotEmpty == true ? record['flightLocation'] : null,
          flightPurpose: record['flightPurpose']?.isNotEmpty == true ? record['flightPurpose'] : null,
          notes: record['notes']?.isNotEmpty == true ? record['notes'] : null,
        );
        imported++;
      }

      // プロバイダー更新
      ref.invalidate(flightLogStorageProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$imported件の飛行記録をExcelからインポートしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excelインポートに失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 飛行記録をCSVエクスポート
  Future<void> _exportFlightsCsv(BuildContext context) async {
    try {
      final storage = await ref.read(flightLogStorageProvider.future);
      final flights = await storage.getAllFlights();

      if (flights.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('エクスポートする飛行記録がありません'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 機体・操縦者の名前マップを構築
      final aircraftNames = <int, String>{};
      final aircraftModels = <int, String>{};
      final pilotNames = <int, String>{};
      final aircraftsAsync = ref.read(aircraftListProvider);
      aircraftsAsync.whenData((list) {
        for (final a in list) {
          aircraftNames[a.id] = a.registrationNumber;
          aircraftModels[a.id] = a.modelName ?? '';
        }
      });
      final pilotsAsync = ref.read(pilotListProvider);
      pilotsAsync.whenData((list) {
        for (final p in list) {
          pilotNames[p.id] = p.name;
        }
      });

      final csvString = CsvService.flightsToCsv(
        flights,
        aircraftNames: aircraftNames,
        aircraftModels: aircraftModels,
        pilotNames: pilotNames,
      );
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      downloadCsvFile(csvString, '飛行記録_$now.csv');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${flights.length}件の飛行記録をエクスポートしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エクスポートに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// バッチ: 全飛行記録を選択
  void _selectAllFlights() async {
    try {
      final storage = await ref.read(flightLogStorageProvider.future);
      final flights = await storage.getAllFlights();
      setState(() {
        if (_selectedFlightIds.length == flights.length) {
          // 全選択済みなら解除
          _selectedFlightIds.clear();
        } else {
          _selectedFlightIds.clear();
          for (final f in flights) {
            _selectedFlightIds.add(f.id);
          }
        }
      });
    } catch (_) {}
  }

  /// バッチ: 選択した飛行記録をCSVエクスポート
  Future<void> _exportSelectedFlightsCsv(BuildContext context) async {
    try {
      final storage = await ref.read(flightLogStorageProvider.future);
      final allFlights = await storage.getAllFlights();
      final selected = allFlights
          .where((f) => _selectedFlightIds.contains(f.id))
          .toList();

      if (selected.isEmpty) return;

      // 機体・操縦者の名前マップを構築
      final aircraftNames = <int, String>{};
      final aircraftModels = <int, String>{};
      final pilotNames = <int, String>{};
      final aircraftsAsync = ref.read(aircraftListProvider);
      aircraftsAsync.whenData((list) {
        for (final a in list) {
          aircraftNames[a.id] = a.registrationNumber;
          aircraftModels[a.id] = a.modelName ?? '';
        }
      });
      final pilotsAsync = ref.read(pilotListProvider);
      pilotsAsync.whenData((list) {
        for (final p in list) {
          pilotNames[p.id] = p.name;
        }
      });

      final csvString = CsvService.flightsToCsv(
        selected,
        aircraftNames: aircraftNames,
        aircraftModels: aircraftModels,
        pilotNames: pilotNames,
      );
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      downloadCsvFile(csvString, '飛行記録_選択_$now.csv');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length}件の飛行記録をエクスポートしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エクスポートに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// バッチ: 選択した飛行記録を削除（確認ダイアログ付き）
  Future<void> _deleteSelectedFlights(BuildContext context) async {
    final count = _selectedFlightIds.length;

    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('飛行記録の一括削除'),
        content: Text('選択した$count件の飛行記録を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final storage = await ref.read(flightLogStorageProvider.future);
      var deleted = 0;
      for (final id in _selectedFlightIds.toList()) {
        await storage.deleteFlight(id);
        deleted++;
      }

      // プロバイダーを更新
      ref.invalidate(flightLogStorageProvider);

      setState(() {
        _selectedFlightIds.clear();
        _batchMode = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deleted件の飛行記録を削除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('削除に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 様式1: 飛行実績タブ（フィルター対応）
class _FlightRecordTab extends ConsumerWidget {
  final int? filterAircraftId;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;
  final bool isFiltered;
  final String searchQuery;
  final String sortKey;
  final TextEditingController searchController;
  final VoidCallback onClearFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSortChanged;
  final bool batchMode;
  final Set<int> selectedIds;
  final void Function(int id, bool selected)? onSelectionChanged;

  const _FlightRecordTab({
    this.filterAircraftId,
    this.filterStartDate,
    this.filterEndDate,
    this.isFiltered = false,
    this.searchQuery = '',
    this.sortKey = 'date_desc',
    required this.searchController,
    required this.onClearFilter,
    required this.onSearchChanged,
    required this.onSortChanged,
    this.batchMode = false,
    this.selectedIds = const {},
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightsAsync = ref.watch(flightListProvider);
    final aircraftsAsync = ref.watch(aircraftListProvider);
    final pilotsAsync = ref.watch(pilotListProvider);

    return Scaffold(
      body: flightsAsync.when(
        data: (allFlights) {
          if (allFlights.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.flight_takeoff,
              title: '飛行実績はまだありません',
              description: '新しい飛行実績を記録するには、下のボタンをタップしてください',
              onActionPressed: () => context.push('/flight-logs/flights/new'),
              actionLabel: '飛行実績を記録',
            );
          }

          // フィルタリング適用
          var flights = List.of(allFlights);
          if (filterAircraftId != null) {
            flights = flights.where((f) => f.aircraftId == filterAircraftId).toList();
          }
          if (filterStartDate != null) {
            final start = DateFormat('yyyy-MM-dd').format(filterStartDate!);
            flights = flights.where((f) => f.flightDate.compareTo(start) >= 0).toList();
          }
          if (filterEndDate != null) {
            final end = DateFormat('yyyy-MM-dd').format(filterEndDate!);
            flights = flights.where((f) => f.flightDate.compareTo(end) <= 0).toList();
          }

          // 機体・パイロット名前マップを作成
          final aircraftMap = <int, String>{};
          final pilotMap = <int, String>{};
          aircraftsAsync.whenData((list) {
            for (final a in list) {
              aircraftMap[a.id] = a.registrationNumber;
            }
          });
          pilotsAsync.whenData((list) {
            for (final p in list) {
              pilotMap[p.id] = p.name;
            }
          });

          // キーワード検索フィルタリング
          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            flights = flights.where((f) {
              final fields = [
                f.takeoffLocation ?? '',
                f.landingLocation ?? '',
                f.flightPurpose ?? '',
                f.flightArea ?? '',
                f.notes ?? '',
                aircraftMap[f.aircraftId] ?? '',
                pilotMap[f.pilotId] ?? '',
              ];
              return fields.any((field) => field.toLowerCase().contains(q));
            }).toList();
          }

          // ソート適用
          switch (sortKey) {
            case 'date_asc':
              flights.sort((a, b) => a.flightDate.compareTo(b.flightDate));
              break;
            case 'duration_desc':
              flights.sort((a, b) => (b.flightDuration ?? 0).compareTo(a.flightDuration ?? 0));
              break;
            case 'location':
              flights.sort((a, b) => (a.takeoffLocation ?? '').compareTo(b.takeoffLocation ?? ''));
              break;
            case 'date_desc':
            default:
              flights.sort((a, b) => b.flightDate.compareTo(a.flightDate));
              break;
          }

          return Column(
            children: [
              // フィルター適用中のバナー
              if (isFiltered)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.amber[50],
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'フィルター適用中: ${flights.length}/${allFlights.length}件',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onClearFilter,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('解除'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber[900],
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),

              // 検索バー・ソートメニュー
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '場所・目的・機体名で検索',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    onSearchChanged('');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        style: const TextStyle(fontSize: 14),
                        onChanged: onSearchChanged,
                        controller: searchController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort),
                      tooltip: '並び替え',
                      onSelected: onSortChanged,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'date_desc',
                          child: Row(
                            children: [
                              Icon(sortKey == 'date_desc' ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 18),
                              const SizedBox(width: 8),
                              const Text('日付（新しい順）'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'date_asc',
                          child: Row(
                            children: [
                              Icon(sortKey == 'date_asc' ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 18),
                              const SizedBox(width: 8),
                              const Text('日付（古い順）'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'duration_desc',
                          child: Row(
                            children: [
                              Icon(sortKey == 'duration_desc' ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 18),
                              const SizedBox(width: 8),
                              const Text('飛行時間（長い順）'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'location',
                          child: Row(
                            children: [
                              Icon(sortKey == 'location' ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 18),
                              const SizedBox(width: 8),
                              const Text('離陸場所（あいうえお順）'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 件数表示
              if (searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '検索結果: ${flights.length}件',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ),

              // リスト
              Expanded(
                child: flights.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              searchQuery.isNotEmpty
                                  ? '「$searchQuery」に一致する飛行記録がありません'
                                  : '条件に一致する飛行記録がありません',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: flights.length,
                        itemBuilder: (context, index) {
                          final flight = flights[index]; // ソート済みなのでそのまま表示
                          final flightNo = 'FLT-${flight.id.toString().padLeft(4, '0')}';
                          final isSelected = selectedIds.contains(flight.id);
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: batchMode && isSelected ? Colors.blue.shade50 : null,
                            child: ListTile(
                              onTap: batchMode
                                  ? () => onSelectionChanged?.call(flight.id, !isSelected)
                                  : () => context.push('/flight-logs/flights/${flight.id}'),
                              onLongPress: !batchMode
                                  ? () {
                                      // ロングプレスでバッチモード開始は親で管理
                                    }
                                  : null,
                              leading: batchMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (v) => onSelectionChanged?.call(flight.id, v ?? false),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(Icons.flight_takeoff, color: Colors.blue, size: 20),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          flightNo,
                                          style: TextStyle(fontSize: 9, color: Colors.blue[700], fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                              title: Row(
                                children: [
                                  Text(flight.flightDate),
                                  if (batchMode) ...[
                                    const SizedBox(width: 6),
                                    Text(flightNo, style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                                  ],
                                  if (flight.photoAttachments.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.photo_camera, size: 14, color: Colors.grey[500]),
                                  ],
                                  if (flight.complianceChecks.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.checklist, size: 14, color: Colors.green[400]),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '${aircraftMap[flight.aircraftId] ?? "機体#${flight.aircraftId}"} / '
                                '${pilotMap[flight.pilotId] ?? "操縦者#${flight.pilotId}"}\n'
                                '${flight.takeoffLocation ?? ""} → ${flight.landingLocation ?? ""}',
                              ),
                              isThreeLine: true,
                              trailing: batchMode
                                  ? null
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          onPressed: () => _confirmDelete(context, ref, flight.id),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_flight',
        onPressed: () => context.push('/flight-logs/flights/new'),
        tooltip: '飛行実績を記録',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('この飛行実績を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(flightFormProvider.notifier).deleteFlight(id);
              Navigator.pop(ctx);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

/// 様式2: 日常点検タブ（フィルター・PDF出力対応）
class _DailyInspectionTab extends ConsumerStatefulWidget {
  const _DailyInspectionTab();

  @override
  ConsumerState<_DailyInspectionTab> createState() => _DailyInspectionTabState();
}

class _DailyInspectionTabState extends ConsumerState<_DailyInspectionTab> {
  int? _filterAircraftId;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _isFiltered = false;

  @override
  Widget build(BuildContext context) {
    final inspectionsAsync = ref.watch(inspectionListProvider);
    final aircraftsAsync = ref.watch(aircraftListProvider);
    final pilotsAsync = ref.watch(pilotListProvider);

    return Scaffold(
      body: inspectionsAsync.when(
        data: (allInspections) {
          if (allInspections.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.checklist,
              title: '点検記録はまだありません',
              description: '新しい日常点検を記録するには、下のボタンをタップしてください',
              onActionPressed: () =>
                  context.push('/flight-logs/inspections/new'),
              actionLabel: '日常点検を記録',
            );
          }

          // フィルタリング
          var inspections = List.of(allInspections);
          if (_filterAircraftId != null) {
            inspections = inspections.where((i) => i.aircraftId == _filterAircraftId).toList();
          }
          if (_filterStartDate != null) {
            final start = DateFormat('yyyy-MM-dd').format(_filterStartDate!);
            inspections = inspections.where((i) => i.inspectionDate.compareTo(start) >= 0).toList();
          }
          if (_filterEndDate != null) {
            final end = DateFormat('yyyy-MM-dd').format(_filterEndDate!);
            inspections = inspections.where((i) => i.inspectionDate.compareTo(end) <= 0).toList();
          }

          final aircraftMap = <int, String>{};
          final pilotMap = <int, String>{};
          aircraftsAsync.whenData((list) {
            for (final a in list) {
              aircraftMap[a.id] = a.registrationNumber;
            }
          });
          pilotsAsync.whenData((list) {
            for (final p in list) {
              pilotMap[p.id] = p.name;
            }
          });

          return Column(
            children: [
              // フィルターバナー
              if (_isFiltered)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.green[50],
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'フィルター適用中: ${inspections.length}/${allInspections.length}件',
                          style: TextStyle(fontSize: 13, color: Colors.green[900], fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _filterAircraftId = null;
                            _filterStartDate = null;
                            _filterEndDate = null;
                            _isFiltered = false;
                          });
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('解除'),
                        style: TextButton.styleFrom(foregroundColor: Colors.green[900]),
                      ),
                    ],
                  ),
                ),

              // フィルター＋CSV/PDF出力ボタン
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showInspectionFilter(context),
                      icon: Icon(Icons.filter_list, size: 16, color: _isFiltered ? Colors.amber : null),
                      label: const Text('絞り込み'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _exportInspectionsCsv(context, inspections),
                      icon: const Icon(Icons.file_download, size: 16),
                      label: const Text('CSV'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),

              // リスト
              Expanded(
                child: inspections.isEmpty
                    ? Center(
                        child: Text('条件に一致する点検記録がありません',
                          style: TextStyle(color: Colors.grey[600])),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: inspections.length,
                        itemBuilder: (context, index) {
                          final insp = inspections[inspections.length - 1 - index];
                          final resultColor = insp.overallResult == '合格'
                              ? Colors.green
                              : insp.overallResult == '不合格'
                                  ? Colors.red
                                  : Colors.orange;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              onTap: () => context.push('/flight-logs/inspections/${insp.id}'),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: resultColor[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.checklist, color: resultColor),
                              ),
                              title: Text(insp.inspectionDate),
                              subtitle: Text(
                                '${aircraftMap[insp.aircraftId] ?? "機体#${insp.aircraftId}"} / '
                                '${pilotMap[insp.inspectorId] ?? "点検者#${insp.inspectorId}"}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: resultColor[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      insp.overallResult,
                                      style: TextStyle(
                                        color: resultColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () => _confirmDelete(context, ref, insp.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_inspection',
        onPressed: () => context.push('/flight-logs/inspections/new'),
        tooltip: '日常点検を記録',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 日常点検フィルターダイアログ
  Future<void> _showInspectionFilter(BuildContext context) async {
    final result = await showDialog<InspectionFilterResult>(
      context: context,
      builder: (ctx) => InspectionFilterDialog(
        initialAircraftId: _filterAircraftId,
        initialStartDate: _filterStartDate,
        initialEndDate: _filterEndDate,
      ),
    );

    if (result == null) return;

    if (result.exportPdf) {
      await _exportInspectionPdf(context, result);
    }

    setState(() {
      _filterAircraftId = result.aircraftId;
      _filterStartDate = result.startDate;
      _filterEndDate = result.endDate;
      _isFiltered = result.aircraftId != null ||
          result.startDate != null ||
          result.endDate != null;
    });
  }

  /// 国交省様式2 PDF出力
  Future<void> _exportInspectionPdf(BuildContext context, InspectionFilterResult filter) async {
    try {
      final storage = await ref.read(flightLogStorageProvider.future);
      var inspections = await storage.getAllInspections();

      if (filter.aircraftId != null) {
        inspections = inspections.where((i) => i.aircraftId == filter.aircraftId).toList();
      }
      if (filter.startDate != null) {
        final start = DateFormat('yyyy-MM-dd').format(filter.startDate!);
        inspections = inspections.where((i) => i.inspectionDate.compareTo(start) >= 0).toList();
      }
      if (filter.endDate != null) {
        final end = DateFormat('yyyy-MM-dd').format(filter.endDate!);
        inspections = inspections.where((i) => i.inspectionDate.compareTo(end) <= 0).toList();
      }

      if (inspections.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('条件に一致する点検記録がありません'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      inspections.sort((a, b) => a.inspectionDate.compareTo(b.inspectionDate));

      String? aircraftName;
      final aircraftsAsync = ref.read(aircraftListProvider);
      aircraftsAsync.whenData((list) {
        if (filter.aircraftId != null) {
          final ac = list.where((a) => a.id == filter.aircraftId).toList();
          if (ac.isNotEmpty) {
            aircraftName = '${ac.first.registrationNumber} - ${ac.first.modelName}';
          }
        }
      });

      final inspectorMap = <int, String>{};
      final pilotsAsync = ref.read(pilotListProvider);
      pilotsAsync.whenData((list) {
        for (final p in list) {
          inspectorMap[p.id] = p.name;
        }
      });

      final pdfBytes = await PdfService.generateInspectionPdf(
        inspections: inspections,
        aircraftName: aircraftName,
        inspectorNames: inspectorMap,
      );

      if (context.mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: '日常点検記録_様式2',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF出力に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 日常点検CSVエクスポート
  void _exportInspectionsCsv(BuildContext context, List<DailyInspectionData> inspections) {
    if (inspections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクスポートする点検記録がありません'), backgroundColor: Colors.orange),
      );
      return;
    }
    final csvString = CsvService.inspectionsToCsv(inspections);
    final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    downloadCsvFile(csvString, '日常点検_$now.csv');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${inspections.length}件の点検記録をエクスポートしました'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('この点検記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(inspectionFormProvider.notifier).deleteInspection(id);
              Navigator.pop(ctx);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

/// 様式3: 整備記録タブ
class _MaintenanceRecordTab extends ConsumerWidget {
  const _MaintenanceRecordTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenancesAsync = ref.watch(maintenanceListProvider);
    final aircraftsAsync = ref.watch(aircraftListProvider);
    final pilotsAsync = ref.watch(pilotListProvider);

    return Scaffold(
      body: maintenancesAsync.when(
        data: (maintenances) {
          if (maintenances.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.build,
              title: '整備記録はまだありません',
              description: '新しい整備記録を登録するには、下のボタンをタップしてください',
              onActionPressed: () =>
                  context.push('/flight-logs/maintenances/new'),
              actionLabel: '整備記録を登録',
            );
          }

          final aircraftMap = <int, String>{};
          final pilotMap = <int, String>{};
          aircraftsAsync.whenData((list) {
            for (final a in list) {
              aircraftMap[a.id] = a.registrationNumber;
            }
          });
          pilotsAsync.whenData((list) {
            for (final p in list) {
              pilotMap[p.id] = p.name;
            }
          });

          return Column(
            children: [
              // エクスポートボタン（CSV + PDF）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _exportMaintenancesCsv(context, maintenances),
                      icon: const Icon(Icons.file_download, size: 16),
                      label: const Text('CSV'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _exportMaintenancesPdf(context, ref, maintenances, pilotMap),
                      icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
                      label: const Text('PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: maintenances.length,
            itemBuilder: (context, index) {
              final maint = maintenances[maintenances.length - 1 - index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  onTap: () => context.push('/flight-logs/maintenances/${maint.id}'),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.build, color: Colors.orange),
                  ),
                  title: Text(
                      '${maint.maintenanceDate} - ${maint.maintenanceType}'),
                  subtitle: Text(
                    '${aircraftMap[maint.aircraftId] ?? "機体#${maint.aircraftId}"} / '
                    '${pilotMap[maint.maintainerId] ?? "整備者#${maint.maintainerId}"}\n'
                    '${maint.description ?? ""}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () =>
                            _confirmDelete(context, ref, maint.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_maintenance',
        onPressed: () => context.push('/flight-logs/maintenances/new'),
        tooltip: '整備記録を登録',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 整備記録PDF（様式3）エクスポート
  Future<void> _exportMaintenancesPdf(
    BuildContext context,
    WidgetRef ref,
    List<MaintenanceRecordData> maintenances,
    Map<int, String> pilotMap,
  ) async {
    if (maintenances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクスポートする整備記録がありません'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final pdfBytes = await PdfService.generateMaintenancePdf(
        maintenances: maintenances,
        maintainerNames: pilotMap,
      );

      if (!context.mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '整備記録_様式3_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF生成に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 整備記録CSVエクスポート
  void _exportMaintenancesCsv(BuildContext context, List<MaintenanceRecordData> maintenances) {
    if (maintenances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクスポートする整備記録がありません'), backgroundColor: Colors.orange),
      );
      return;
    }
    final csvString = CsvService.maintenancesToCsv(maintenances);
    final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    downloadCsvFile(csvString, '整備記録_$now.csv');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${maintenances.length}件の整備記録をエクスポートしました'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('この整備記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref
                  .read(maintenanceFormProvider.notifier)
                  .deleteMaintenance(id);
              Navigator.pop(ctx);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
