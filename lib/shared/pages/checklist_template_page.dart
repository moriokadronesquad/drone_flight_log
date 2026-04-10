import 'package:flutter/material.dart';
import '../../core/services/checklist_template_service.dart';

/// チェックリストテンプレート管理ページ
///
/// テンプレートの一覧表示・作成・編集・削除
class ChecklistTemplatePage extends StatefulWidget {
  const ChecklistTemplatePage({super.key});

  @override
  State<ChecklistTemplatePage> createState() => _ChecklistTemplatePageState();
}

class _ChecklistTemplatePageState extends State<ChecklistTemplatePage> {
  List<ChecklistTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final templates = await ChecklistTemplateService.getAll();
    if (mounted) {
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チェックリストテンプレート'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('テンプレートがありません',
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final t = _templates[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.checklist, color: Colors.blue.shade700),
                        ),
                        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${t.items.length}項目${t.description.isNotEmpty ? " - ${t.description}" : ""}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                ...t.items.asMap().entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${entry.key + 1}. ',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                        Expanded(
                                          child: Text(
                                            entry.value,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('編集'),
                                      onPressed: () => _editTemplate(t),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                      label: const Text('削除', style: TextStyle(color: Colors.red)),
                                      onPressed: () => _confirmDelete(t),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTemplate,
        tooltip: '新規テンプレート',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// テンプレート作成ダイアログ
  Future<void> _createTemplate() async {
    final result = await _showTemplateEditor(null);
    if (result != null) {
      await ChecklistTemplateService.add(result);
      await _loadTemplates();
    }
  }

  /// テンプレート編集
  Future<void> _editTemplate(ChecklistTemplate template) async {
    final result = await _showTemplateEditor(template);
    if (result != null) {
      await ChecklistTemplateService.update(result);
      await _loadTemplates();
    }
  }

  /// テンプレート削除確認
  Future<void> _confirmDelete(ChecklistTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('テンプレート削除'),
        content: Text('「${template.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ChecklistTemplateService.delete(template.id);
      await _loadTemplates();
    }
  }

  /// テンプレート作成・編集ダイアログ
  Future<ChecklistTemplate?> _showTemplateEditor(ChecklistTemplate? existing) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final items = List<String>.from(existing?.items ?? []);
    final itemController = TextEditingController();

    return showDialog<ChecklistTemplate>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? '新規テンプレート' : 'テンプレート編集'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'テンプレート名',
                          hintText: '例: 通常飛行',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: '説明（任意）',
                          hintText: '例: 一般的な飛行前チェック',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'チェック項目（${items.length}件）',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      // 項目リスト
                      ...items.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text('${entry.key + 1}.', style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(entry.value, style: const TextStyle(fontSize: 13)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setDialogState(() => items.removeAt(entry.key));
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      // 新規項目入力
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: itemController,
                              decoration: const InputDecoration(
                                hintText: '新しいチェック項目を追加',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  setDialogState(() {
                                    items.add(value.trim());
                                    itemController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.blue),
                            onPressed: () {
                              if (itemController.text.trim().isNotEmpty) {
                                setDialogState(() {
                                  items.add(itemController.text.trim());
                                  itemController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('テンプレート名を入力してください')),
                      );
                      return;
                    }
                    if (items.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('チェック項目を1つ以上追加してください')),
                      );
                      return;
                    }

                    final template = ChecklistTemplate(
                      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      description: descController.text.trim(),
                      items: items,
                      createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
                    );
                    Navigator.pop(ctx, template);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
