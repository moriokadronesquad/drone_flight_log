import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/local_storage.dart';
import '../../../../core/services/csv_service.dart';
import '../../../../core/services/download_helper.dart';
import '../../domain/entities/pilot.dart';
import '../providers/pilot_provider.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/confirm_dialog.dart';

/// パイロット一覧ページ
/// 登録されたすべてのパイロットを表示し、追加・編集・削除・インポート・エクスポート機能を提供
class PilotListPage extends ConsumerStatefulWidget {
  const PilotListPage({super.key});

  @override
  ConsumerState<PilotListPage> createState() => _PilotListPageState();
}

class _PilotListPageState extends ConsumerState<PilotListPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pilotListAsync = ref.watch(pilotListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('操縦者管理'),
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
      body: pilotListAsync.when(
        data: (allPilots) {
          if (allPilots.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.person_add,
              title: '登録された操縦者はありません',
              description: '新しい操縦者を登録するには、下のボタンをタップしてください',
              onActionPressed: () {
                context.push('/pilots/new');
              },
              actionLabel: '新規登録',
            );
          }

          // 検索フィルタリング
          var pilots = allPilots;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            pilots = pilots.where((p) {
              return p.name.toLowerCase().contains(q) ||
                  (p.licenseNumber?.toLowerCase().contains(q) ?? false) ||
                  (p.licenseType?.toLowerCase().contains(q) ?? false) ||
                  (p.organization?.toLowerCase().contains(q) ?? false);
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
                    hintText: '名前・免許番号・所属で検索',
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
                      '検索結果: ${pilots.length}件',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ),
              Expanded(
                child: pilots.isEmpty
                    ? Center(
                        child: Text(
                          '「$_searchQuery」に一致する操縦者がいません',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: pilots.length,
                        itemBuilder: (context, index) {
                          final pilot = pilots[index];
                          return _PilotListItem(
                            pilot: pilot,
                            onTap: () {
                              context.push('/pilots/${pilot.id}/edit');
                            },
                            onDelete: () {
                              _showDeleteConfirmDialog(context, ref, pilot);
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
          context.push('/pilots/new');
        },
        tooltip: '新しい操縦者を登録',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// CSVエクスポート処理
  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final storage = await ref.read(localStorageProvider.future);
      final pilots = storage.getAllPilotsSync();

      if (pilots.isEmpty) {
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

      final csvString = CsvService.pilotsToCsv(pilots);
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '操縦者データ_$now.csv';

      downloadCsvFile(csvString, fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pilots.length}件の操縦者データをエクスポートしました'),
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
      final dataList = CsvService.parsePilotCsv(csvString);

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
            content: Text('${dataList.length}件の操縦者データをインポートしますか？'),
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
      final count = await storage.importPilots(dataList);

      // リスト更新
      ref.invalidate(pilotListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count件の操縦者データをインポートしました'),
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
    Pilot pilot,
  ) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: '操縦者を削除',
        message: '${pilot.name}を削除してもよろしいですか？',
        confirmText: '削除',
        cancelText: 'キャンセル',
        onConfirm: () async {
          final formNotifier = ref.read(pilotFormProvider.notifier);
          await formNotifier.deletePilot(pilot.id);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

/// パイロットリストアイテムウィジェット
class _PilotListItem extends StatelessWidget {
  final Pilot pilot;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PilotListItem({
    required this.pilot,
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
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.person,
            color: Colors.green,
          ),
        ),
        title: Text(
          pilot.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pilot.licenseType != null)
              Text(
                '免許: ${pilot.licenseType}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (pilot.organization != null)
              Text(
                pilot.organization!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onTap();
            } else if (value == 'delete') {
              onDelete();
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
}
