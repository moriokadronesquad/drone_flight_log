import 'package:flutter/material.dart';
import '../../core/services/audit_log_service.dart';

/// 操作ログ閲覧ページ
/// データの追加・編集・削除の履歴を確認できる
class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  List<AuditLogEntry> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await AuditLogService.getAll();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('操作ログ'),
        elevation: 0,
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'ログをクリア',
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('操作ログはまだありません',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return _LogTile(entry: log);
                  },
                ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ログをクリア'),
        content: const Text('すべての操作ログを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              await AuditLogService.clear();
              if (ctx.mounted) Navigator.pop(ctx);
              _loadLogs();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('クリア'),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final AuditLogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final actionIcon = _getActionIcon(entry.action);
    final actionColor = _getActionColor(entry.action);

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: actionColor.withOpacity(0.1),
        child: Icon(actionIcon, size: 16, color: actionColor),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: actionColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.action,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: actionColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(entry.target, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.detail != null && entry.detail!.isNotEmpty)
            Text(entry.detail!, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(entry.timestamp, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case '作成': return Icons.add_circle_outline;
      case '更新': return Icons.edit;
      case '削除': return Icons.delete_outline;
      case 'エクスポート': return Icons.file_download;
      case 'インポート': return Icons.file_upload;
      case 'バックアップ': return Icons.backup;
      case 'リストア': return Icons.restore;
      case 'ログイン': return Icons.login;
      case '設定変更': return Icons.settings;
      default: return Icons.history;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case '作成': return Colors.green;
      case '更新': return Colors.blue;
      case '削除': return Colors.red;
      case 'エクスポート': return Colors.teal;
      case 'インポート': return Colors.orange;
      case 'バックアップ': return Colors.indigo;
      case 'リストア': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
