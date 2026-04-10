import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../core/database/local_storage.dart';
import '../../core/services/csv_service.dart';
import '../../core/services/download_helper.dart';
import '../../features/aircraft/domain/entities/aircraft.dart';
import '../../features/aircraft/presentation/providers/aircraft_provider.dart';
import '../../features/pilot/domain/entities/pilot.dart';
import '../../features/pilot/presentation/providers/pilot_provider.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/drone_icon.dart';

/// マスタ管理ページ
/// 機体管理と操縦者管理をタブで切り替えて表示する統合ページ
class MasterManagementPage extends ConsumerStatefulWidget {
  final int initialTab;
  const MasterManagementPage({super.key, this.initialTab = 0});

  @override
  ConsumerState<MasterManagementPage> createState() => _MasterManagementPageState();
}

class _MasterManagementPageState extends ConsumerState<MasterManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _aircraftSearch = '';
  String _pilotSearch = '';
  final _aircraftSearchController = TextEditingController();
  final _pilotSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    // タブ切替時にFABを更新するためにsetStateを呼ぶ
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aircraftSearchController.dispose();
    _pilotSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マスタ管理'),
        elevation: 0,
        actions: [
          // CSVインポート
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'CSVインポート',
            onPressed: () {
              if (_tabController.index == 0) {
                _importAircraftCsv(context);
              } else {
                _importPilotCsv(context);
              }
            },
          ),
          // CSVエクスポート
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'CSVエクスポート',
            onPressed: () {
              if (_tabController.index == 0) {
                _exportAircraftCsv(context);
              } else {
                _exportPilotCsv(context);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: DroneIcon(size: 24, color: Theme.of(context).colorScheme.primary), text: '機体'),
            const Tab(icon: Icon(Icons.person), text: '操縦者'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAircraftTab(),
          _buildPilotTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final currentTab = _tabController.index;
          if (currentTab == 0) {
            await context.push('/aircrafts/new');
          } else {
            await context.push('/pilots/new');
          }
          // フォームから戻った後にタブを復元
          if (mounted) {
            _tabController.animateTo(currentTab);
          }
        },
        tooltip: _tabController.index == 0 ? '機体を追加' : '操縦者を追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  // =====================
  // 機体タブ
  // =====================
  Widget _buildAircraftTab() {
    final aircraftListAsync = ref.watch(aircraftListProvider);

    return aircraftListAsync.when(
      data: (allAircrafts) {
        if (allAircrafts.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.airplanemode_active,
            title: '登録された機体はありません',
            description: '新しい機体を登録するには、下のボタンをタップしてください',
            onActionPressed: () => context.push('/aircrafts/new'),
            actionLabel: '新規登録',
          );
        }

        var aircrafts = allAircrafts;
        if (_aircraftSearch.isNotEmpty) {
          final q = _aircraftSearch.toLowerCase();
          aircrafts = aircrafts.where((a) {
            return a.registrationNumber.toLowerCase().contains(q) ||
                (a.modelName?.toLowerCase().contains(q) ?? false) ||
                (a.manufacturer?.toLowerCase().contains(q) ?? false) ||
                a.aircraftType.toLowerCase().contains(q);
          }).toList();
        }

        return Column(
          children: [
            // 検索バー
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _aircraftSearchController,
                decoration: InputDecoration(
                  hintText: '登録番号・機種名・メーカーで検索',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _aircraftSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _aircraftSearchController.clear();
                            setState(() => _aircraftSearch = '');
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
                onChanged: (v) => setState(() => _aircraftSearch = v),
              ),
            ),
            if (_aircraftSearch.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '検索結果: ${aircrafts.length}件',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ),
            Expanded(
              child: aircrafts.isEmpty
                  ? Center(
                      child: Text(
                        '「$_aircraftSearch」に一致する機体がありません',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: aircrafts.length,
                      itemBuilder: (context, index) {
                        final aircraft = aircrafts[index];
                        return _buildAircraftItem(aircraft);
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
    );
  }

  Widget _buildAircraftItem(Aircraft aircraft) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const DroneIcon(size: 24, color: Colors.blue),
        ),
        title: Text(aircraft.registrationNumber),
        subtitle: Text(
          aircraft.modelName ?? aircraft.aircraftType,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              context.push('/aircrafts/${aircraft.id}/edit');
            } else if (value == 'delete') {
              _confirmDeleteAircraft(aircraft);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('編集')])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('削除', style: TextStyle(color: Colors.red))])),
          ],
        ),
        onTap: () => context.push('/aircrafts/${aircraft.id}/edit'),
      ),
    );
  }

  void _confirmDeleteAircraft(Aircraft aircraft) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: '機体を削除',
        message: '${aircraft.registrationNumber}を削除してもよろしいですか？',
        confirmText: '削除',
        cancelText: 'キャンセル',
        onConfirm: () async {
          await ref.read(aircraftFormProvider.notifier).deleteAircraft(aircraft.id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // =====================
  // 操縦者タブ
  // =====================
  Widget _buildPilotTab() {
    final pilotListAsync = ref.watch(pilotListProvider);

    return pilotListAsync.when(
      data: (allPilots) {
        if (allPilots.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.person_add,
            title: '登録された操縦者はありません',
            description: '新しい操縦者を登録するには、下のボタンをタップしてください',
            onActionPressed: () => context.push('/pilots/new'),
            actionLabel: '新規登録',
          );
        }

        var pilots = allPilots;
        if (_pilotSearch.isNotEmpty) {
          final q = _pilotSearch.toLowerCase();
          pilots = pilots.where((p) {
            return p.name.toLowerCase().contains(q) ||
                (p.licenseNumber?.toLowerCase().contains(q) ?? false) ||
                (p.licenseType?.toLowerCase().contains(q) ?? false) ||
                (p.organization?.toLowerCase().contains(q) ?? false);
          }).toList();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _pilotSearchController,
                decoration: InputDecoration(
                  hintText: '名前・免許番号・所属で検索',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _pilotSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _pilotSearchController.clear();
                            setState(() => _pilotSearch = '');
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
                onChanged: (v) => setState(() => _pilotSearch = v),
              ),
            ),
            if (_pilotSearch.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '検索結果: ${pilots.length}件',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ),
            Expanded(
              child: pilots.isEmpty
                  ? Center(
                      child: Text(
                        '「$_pilotSearch」に一致する操縦者がいません',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: pilots.length,
                      itemBuilder: (context, index) {
                        final pilot = pilots[index];
                        return _buildPilotItem(pilot);
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('エラー: $e')),
    );
  }

  Widget _buildPilotItem(Pilot pilot) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.person, color: Colors.green),
        ),
        title: Text(pilot.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pilot.licenseType != null)
              Text('免許: ${pilot.licenseType}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            if (pilot.organization != null)
              Text(pilot.organization!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await context.push('/pilots/${pilot.id}/edit');
              if (mounted) _tabController.animateTo(1);
            } else if (value == 'delete') {
              _confirmDeletePilot(pilot);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('編集')])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('削除', style: TextStyle(color: Colors.red))])),
          ],
        ),
        onTap: () async {
          await context.push('/pilots/${pilot.id}/edit');
          if (mounted) _tabController.animateTo(1);
        },
      ),
    );
  }

  void _confirmDeletePilot(Pilot pilot) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: '操縦者を削除',
        message: '${pilot.name}を削除してもよろしいですか？',
        confirmText: '削除',
        cancelText: 'キャンセル',
        onConfirm: () async {
          await ref.read(pilotFormProvider.notifier).deletePilot(pilot.id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // =====================
  // CSV インポート/エクスポート
  // =====================
  Future<void> _exportAircraftCsv(BuildContext context) async {
    try {
      final storage = await ref.read(localStorageProvider.future);
      final aircrafts = storage.getAllAircraftsSync();
      if (aircrafts.isEmpty) {
        _showSnack('エクスポートするデータがありません', Colors.orange);
        return;
      }
      final csv = CsvService.aircraftsToCSv(aircrafts);
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      downloadCsvFile(csv, '機体データ_$now.csv');
      _showSnack('${aircrafts.length}件の機体データをエクスポートしました', Colors.green);
    } catch (e) {
      _showSnack('エクスポートに失敗: $e', Colors.red);
    }
  }

  Future<void> _exportPilotCsv(BuildContext context) async {
    try {
      final storage = await ref.read(localStorageProvider.future);
      final pilots = storage.getAllPilotsSync();
      if (pilots.isEmpty) {
        _showSnack('エクスポートするデータがありません', Colors.orange);
        return;
      }
      final csv = CsvService.pilotsToCsv(pilots);
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      downloadCsvFile(csv, '操縦者データ_$now.csv');
      _showSnack('${pilots.length}件の操縦者データをエクスポートしました', Colors.green);
    } catch (e) {
      _showSnack('エクスポートに失敗: $e', Colors.red);
    }
  }

  Future<void> _importAircraftCsv(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv'], withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) { _showSnack('ファイルの読み込みに失敗', Colors.red); return; }

      final csvString = utf8.decode(bytes);
      final dataList = CsvService.parseAircraftCsv(csvString);
      if (dataList.isEmpty) { _showSnack('インポートできるデータがありません', Colors.orange); return; }

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('インポート確認'),
          content: Text('${dataList.length}件の機体データをインポートしますか？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('インポート')),
          ],
        ),
      );
      if (confirmed != true) return;

      final storage = await ref.read(localStorageProvider.future);
      final count = await storage.importAircrafts(dataList);
      ref.invalidate(aircraftListProvider);
      _showSnack('$count件の機体データをインポートしました', Colors.green);
    } catch (e) {
      _showSnack('インポートに失敗: $e', Colors.red);
    }
  }

  Future<void> _importPilotCsv(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv'], withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) { _showSnack('ファイルの読み込みに失敗', Colors.red); return; }

      final csvString = utf8.decode(bytes);
      final dataList = CsvService.parsePilotCsv(csvString);
      if (dataList.isEmpty) { _showSnack('インポートできるデータがありません', Colors.orange); return; }

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('インポート確認'),
          content: Text('${dataList.length}件の操縦者データをインポートしますか？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('インポート')),
          ],
        ),
      );
      if (confirmed != true) return;

      final storage = await ref.read(localStorageProvider.future);
      final count = await storage.importPilots(dataList);
      ref.invalidate(pilotListProvider);
      _showSnack('$count件の操縦者データをインポートしました', Colors.green);
    } catch (e) {
      _showSnack('インポートに失敗: $e', Colors.red);
    }
  }

  void _showSnack(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }
}
