import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';

/// 監督者選択結果
class SupervisorSelectionResult {
  final List<int> selectedPilotIds;
  final List<String> selectedPilotNames;

  SupervisorSelectionResult({
    required this.selectedPilotIds,
    required this.selectedPilotNames,
  });
}

/// 監督者選択ウィジェット
///
/// 飛行記録ページから呼び出し、登録済みの操縦者一覧から
/// チェックボックスで監督者を選択する。
/// 選択した監督者は飛行実績・日常点検・整備記録に自動反映される。
class SupervisorSelector extends ConsumerStatefulWidget {
  /// 現在選択済みの監督者ID
  final List<int> initialSelectedIds;

  const SupervisorSelector({
    super.key,
    this.initialSelectedIds = const [],
  });

  @override
  ConsumerState<SupervisorSelector> createState() => _SupervisorSelectorState();
}

class _SupervisorSelectorState extends ConsumerState<SupervisorSelector> {
  late Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<int>.from(widget.initialSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final pilotsAsync = ref.watch(pilotListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('監督者の選択'),
        actions: [
          TextButton.icon(
            onPressed: () {
              // 選択結果を返す
              final pilotsData = ref.read(pilotListProvider);
              final names = <String>[];
              pilotsData.whenData((pilots) {
                for (final p in pilots) {
                  if (_selectedIds.contains(p.id)) {
                    names.add(p.name);
                  }
                }
              });

              Navigator.pop(
                context,
                SupervisorSelectionResult(
                  selectedPilotIds: _selectedIds.toList(),
                  selectedPilotNames: names,
                ),
              );
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('決定', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: pilotsAsync.when(
        data: (pilots) {
          if (pilots.isEmpty) {
            return const Center(
              child: Text('操縦者が登録されていません。\n先に操縦者を登録してください。'),
            );
          }

          return Column(
            children: [
              // 選択状態のサマリー
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.blue[50],
                child: Row(
                  children: [
                    const Icon(Icons.supervisor_account, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedIds.length}名選択中',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const Spacer(),
                    if (_selectedIds.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedIds.clear());
                        },
                        child: const Text('全解除'),
                      ),
                  ],
                ),
              ),

              // 操縦者リスト（チェックボックス付き）
              Expanded(
                child: ListView.builder(
                  itemCount: pilots.length,
                  itemBuilder: (context, index) {
                    final pilot = pilots[index];
                    final isSelected = _selectedIds.contains(pilot.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedIds.add(pilot.id);
                          } else {
                            _selectedIds.remove(pilot.id);
                          }
                        });
                      },
                      title: Text(pilot.name),
                      subtitle: Text(
                        pilot.licenseNumber ?? '資格番号未登録',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      secondary: CircleAvatar(
                        backgroundColor: isSelected
                            ? Colors.blue
                            : Colors.grey[300],
                        child: Icon(
                          Icons.person,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                      activeColor: Colors.blue,
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
    );
  }
}

/// 監督者表示チップ（飛行記録フォーム等で使用）
class SupervisorChips extends StatelessWidget {
  final List<String> supervisorNames;
  final VoidCallback? onEdit;

  const SupervisorChips({
    super.key,
    required this.supervisorNames,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (supervisorNames.isEmpty) {
      return OutlinedButton.icon(
        onPressed: onEdit,
        icon: const Icon(Icons.supervisor_account, size: 18),
        label: const Text('監督者を追加'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.supervisor_account, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  '監督者 (${supervisorNames.length}名)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const Spacer(),
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    child: const Icon(Icons.edit, size: 16, color: Colors.blue),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: supervisorNames.map((name) => Chip(
                label: Text(name, style: const TextStyle(fontSize: 12)),
                avatar: const Icon(Icons.person, size: 16),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
