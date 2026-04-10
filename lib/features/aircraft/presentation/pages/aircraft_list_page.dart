import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/local_storage.dart';
import '../../../../core/services/csv_service.dart';
import '../../../../core/services/download_helper.dart';
import '../../domain/entities/aircraft.dart';
import '../providers/aircraft_provider.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../core/services/qr_share_service.dart';
import '../../../../shared/widgets/confirm_dialog.dart';

/// 航空機一覧ページ
/// 登録されたすべての航空機を表示し、追加・編集・削除・インポート・エクスポート機能を提供
class AircraftListPage extends ConsumerStatefulWidget {
  const AircraftListPage({super.key});

  @override
  ConsumerState<AircraftListPage> createState() => _AircraftListPageState();
}

class _AircraftListPageState extends ConsumerState<AircraftListPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aircraftListAsync = ref.watch(aircraftListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('機体管理'),
        elevation: 0,
        actions: [
          // インポートボタン
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'CSVインポート',
            onPressed: () => _importCsv(context, ref),
          ),
          // エクスポートボタン
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'CSVエクスポート',
            onPressed: () => _exportCsv(context, ref),
          ),
        ],
      ),
      body: aircraftListAsync.when(
        data: (allAircrafts) {
          if (allAircrafts.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.airplanemode_active,
              title: '登録された機体はありません',
              description: '新しい機体を登録するには、下のボタンをタップしてください',
              onActionPressed: () {
                context.push('/aircrafts/new');
              },
              actionLabel: '新規登録',
            );
          }

          // 検索フィルタリング
          var aircrafts = allAircrafts;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            aircrafts = aircrafts.where((a) {
              return a.registrationNumber.toLowerCase().contains(q) ||
                  (a.modelName?.toLowerCase().contains(q) ?? false) ||
                  (a.manufacturer?.toLowerCase().contains(q) ?? false) ||
                  a.aircraftType.toLowerCase().contains(q) ||
                  (a.serialNumber?.toLowerCase().contains(q) ?? false);
            }).toList();
          }

          return Column(
            children: [
              // 検索バー
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '登録番号・機種名・メーカーで検索',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
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
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              if (_searchQuery.isNotEmpty)
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
                          '「$_searchQuery」に一致する機体がありません',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: aircrafts.length,
                        itemBuilder: (context, index) {
                          final aircraft = aircrafts[index];
                          return _AircraftListItem(
                            aircraft: aircraft,
                            onTap: () {
                              context.push('/aircrafts/${aircraft.id}/edit');
                            },
                            onDelete: () {
                              _showDeleteConfirmDialog(context, ref, aircraft);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'エラーが発生しました',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/aircrafts/new');
        },
        tooltip: '新しい機体を登録',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// CSVエクスポート処理
  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final storage = await ref.read(localStorageProvider.future);
      final aircrafts = storage.getAllAircraftsSync();

      if (aircrafts.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('エクスポートするデータがありません'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final csvString = CsvService.aircraftsToCSv(aircrafts);
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '機体データ_$now.csv';

      downloadCsvFile(csvString, fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${aircrafts.length}件の機体データをエクスポートしました'),
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

  /// CSVインポート処理
  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ファイルの読み込みに失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final csvString = utf8.decode(file.bytes!);
      final dataList = CsvService.parseAircraftCsv(csvString);

      if (dataList.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('インポートできるデータが見つかりませんでした'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 確認ダイアログを表示
      if (context.mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('インポート確認'),
            content: Text('${dataList.length}件の機体データをインポートしますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('インポート'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }

      final storage = await ref.read(localStorageProvider.future);
      final count = await storage.importAircrafts(dataList);

      // リスト更新
      ref.invalidate(aircraftListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count件の機体データをインポートしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('インポートに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 削除確認ダイアログを表示
  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    Aircraft aircraft,
  ) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '機体を削除',
        message: '${aircraft.registrationNumber}を削除してもよろしいですか？',
        confirmText: '削除',
        cancelText: 'キャンセル',
        onConfirm: () async {
          final formNotifier = ref.read(aircraftFormProvider.notifier);
          await formNotifier.deleteAircraft(aircraft.id);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

/// 航空機リストアイテムウィジェット
class _AircraftListItem extends StatelessWidget {
  final Aircraft aircraft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AircraftListItem({
    required this.aircraft,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getAircraftIcon(),
            color: Colors.blue,
          ),
        ),
        title: Text(
          aircraft.modelName ?? aircraft.aircraftType,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          aircraft.registrationNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onTap();
            } else if (value == 'delete') {
              onDelete();
            } else if (value == 'qr') {
              QrShareService.showAircraftQrDialog(context, aircraft);
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('編集'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'qr',
              child: Row(
                children: [
                  Icon(Icons.qr_code_2, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('QRコード表示'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('削除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  /// 航空機の種類に応じたアイコンを取得
  IconData _getAircraftIcon() {
    final type = aircraft.aircraftType;
    if (type.contains('マルチ')) {
      return Icons.flight;
    } else if (type.contains('固定')) {
      return Icons.airplanemode_active;
    } else if (type.contains('VTOL')) {
      return Icons.airplanemode_active;
    } else {
      return Icons.airplanemode_inactive;
    }
  }
}
