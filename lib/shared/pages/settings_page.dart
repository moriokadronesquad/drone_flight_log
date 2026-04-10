import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/local_storage.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/data_health_service.dart';
import '../../core/services/excel_export_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/app_lock_service.dart';
import '../../core/services/reminder_scheduler_service.dart';
import '../../core/services/auto_backup_service.dart';
import '../../core/services/audit_log_service.dart';
import '../../core/services/anonymize_export_service.dart';
import 'package:printing/printing.dart';
import '../../core/services/google_calendar_service.dart';
import '../../features/flight_log/presentation/providers/flight_log_provider.dart';
import '../../features/aircraft/presentation/providers/aircraft_provider.dart';
import '../../features/pilot/presentation/providers/pilot_provider.dart';

// Web用: ダウンロード/アップロード処理
import '../../core/services/download_helper.dart';
import 'package:file_picker/file_picker.dart';

/// 設定ページ
/// バックアップ・リストア、テーマ切替、データ管理、バージョン情報
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Map<String, int> _dataSummary = {};
  bool _isLoading = false;
  bool _reminderEnabled = true;
  bool _appLockEnabled = false;
  bool _autoBackupEnabled = false;
  int _autoBackupInterval = 7;
  String _lastBackupFormatted = '未実行';
  bool _googleCalendarConnected = false;

  @override
  void initState() {
    super.initState();
    _loadDataSummary();
    _loadReminderSetting();
    _loadAppLockSetting();
    _loadAutoBackupSetting();
    _checkGoogleCalendar();
  }

  Future<void> _checkGoogleCalendar() async {
    final connected = await GoogleCalendarService.signInSilently();
    if (mounted) setState(() => _googleCalendarConnected = connected);
  }

  Future<void> _loadDataSummary() async {
    final summary = await BackupService.getDataSummary();
    if (mounted) setState(() => _dataSummary = summary);
  }

  Future<void> _loadReminderSetting() async {
    final enabled = await ReminderSchedulerService.isEnabled();
    if (mounted) setState(() => _reminderEnabled = enabled);
  }

  Future<void> _loadAppLockSetting() async {
    final enabled = await AppLockService.isEnabled();
    if (mounted) setState(() => _appLockEnabled = enabled);
  }

  Future<void> _loadAutoBackupSetting() async {
    final enabled = await AutoBackupService.isEnabled();
    final interval = await AutoBackupService.getInterval();
    final lastBackup = await AutoBackupService.getLastBackupDateFormatted();
    if (mounted) {
      setState(() {
        _autoBackupEnabled = enabled;
        _autoBackupInterval = interval;
        _lastBackupFormatted = lastBackup;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ─── テーマ設定 ───
                const _SectionHeader(title: '外観'),
                ListTile(
                  leading: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? Colors.amber : Colors.blue,
                  ),
                  title: const Text('テーマ'),
                  subtitle: Text(_themeModeLabel(themeMode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeSelector(context),
                ),
                // アプリロック（PIN）
                SwitchListTile(
                  secondary: Icon(
                    Icons.lock_outline,
                    color: _appLockEnabled ? Colors.red : Colors.grey,
                  ),
                  title: const Text('アプリロック'),
                  subtitle: Text(
                    _appLockEnabled ? 'PINコードで保護中' : '起動時のPIN入力を設定',
                  ),
                  value: _appLockEnabled,
                  onChanged: (value) {
                    if (value) {
                      _showSetPinDialog(context);
                    } else {
                      _showDisablePinDialog(context);
                    }
                  },
                ),

                // リマインダー通知
                SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_active,
                    color: _reminderEnabled ? Colors.orange : Colors.grey,
                  ),
                  title: const Text('飛行予定リマインダー'),
                  subtitle: Text(
                    _reminderEnabled
                        ? '予定前に通知でお知らせします'
                        : '通知はオフです（Web版では非対応）',
                  ),
                  value: _reminderEnabled,
                  onChanged: (value) async {
                    setState(() => _reminderEnabled = value);
                    await ReminderSchedulerService.setEnabled(value);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value
                              ? 'リマインダー通知を有効にしました'
                              : 'リマインダー通知を無効にしました'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),

                // 自動バックアップ
                SwitchListTile(
                  secondary: Icon(
                    Icons.backup,
                    color: _autoBackupEnabled ? Colors.indigo : Colors.grey,
                  ),
                  title: const Text('自動バックアップ'),
                  subtitle: Text(
                    _autoBackupEnabled
                        ? '$_autoBackupInterval日ごとに自動保存（最終: $_lastBackupFormatted）'
                        : '定期的な自動バックアップを設定',
                  ),
                  value: _autoBackupEnabled,
                  onChanged: (value) async {
                    setState(() => _autoBackupEnabled = value);
                    await AutoBackupService.setEnabled(value);
                    await AuditLogService.log(
                      action: AuditAction.setting,
                      target: '自動バックアップ',
                      detail: value ? '有効に変更' : '無効に変更',
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value
                              ? '自動バックアップを有効にしました'
                              : '自動バックアップを無効にしました'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                if (_autoBackupEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('バックアップ間隔: ', style: TextStyle(fontSize: 13)),
                        DropdownButton<int>(
                          value: _autoBackupInterval,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('毎日')),
                            DropdownMenuItem(value: 3, child: Text('3日')),
                            DropdownMenuItem(value: 7, child: Text('7日')),
                            DropdownMenuItem(value: 14, child: Text('14日')),
                            DropdownMenuItem(value: 30, child: Text('30日')),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _autoBackupInterval = value);
                            await AutoBackupService.setInterval(value);
                          },
                        ),
                      ],
                    ),
                  ),
                const Divider(),

                // ─── Googleカレンダー連携 ───
                const _SectionHeader(title: 'Googleカレンダー連携'),
                ListTile(
                  leading: Icon(
                    Icons.event,
                    color: _googleCalendarConnected ? Colors.green : Colors.grey,
                  ),
                  title: const Text('Googleカレンダー'),
                  subtitle: Text(
                    _googleCalendarConnected
                        ? '接続中: ${GoogleCalendarService.userEmail ?? ""}'
                        : '未接続（飛行予定をカレンダーに登録できます）',
                  ),
                  trailing: _googleCalendarConnected
                      ? TextButton(
                          onPressed: () async {
                            await GoogleCalendarService.signOut();
                            setState(() => _googleCalendarConnected = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Googleカレンダーの接続を解除しました'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                          child: const Text('接続解除'),
                        )
                      : ElevatedButton.icon(
                          onPressed: () async {
                            final success = await GoogleCalendarService.signIn();
                            if (mounted) {
                              setState(() => _googleCalendarConnected = success);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Googleカレンダーに接続しました'
                                      : '接続に失敗しました。再度お試しください'),
                                  backgroundColor: success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('接続'),
                        ),
                ),
                const Divider(),

                // ─── データ概要 ───
                const _SectionHeader(title: 'データ管理'),
                if (_dataSummary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dataSummary.entries.map((e) {
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              '${e.value}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                          label: Text(e.key, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                    ),
                  ),

                // チェックリストテンプレート管理
                ListTile(
                  leading: const Icon(Icons.playlist_add_check, color: Colors.teal),
                  title: const Text('チェックリストテンプレート'),
                  subtitle: const Text('フライト前チェックリストの項目を管理'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => GoRouter.of(context).push('/checklist-templates'),
                ),

                // 操作ログ
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.indigo),
                  title: const Text('操作ログ'),
                  subtitle: const Text('データの追加・変更・削除の履歴'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => GoRouter.of(context).push('/audit-log'),
                ),

                // データヘルスチェック
                ListTile(
                  leading: const Icon(Icons.health_and_safety, color: Colors.blue),
                  title: const Text('データ整合性チェック'),
                  subtitle: const Text('孤立データ・重複・不整合を検出'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _runHealthCheck(context),
                ),

                // バックアップ
                ListTile(
                  leading: const Icon(Icons.backup, color: Colors.green),
                  title: const Text('データをバックアップ'),
                  subtitle: const Text('全データをJSONファイルとしてエクスポート'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportBackup(context),
                ),

                // Excel エクスポート
                ListTile(
                  leading: Icon(Icons.table_chart, color: Colors.green.shade700),
                  title: const Text('Excelエクスポート'),
                  subtitle: const Text('全データを.xlsxファイルとしてエクスポート'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportExcel(context),
                ),

                // 匿名化エクスポート
                ListTile(
                  leading: Icon(Icons.privacy_tip, color: Colors.purple.shade600),
                  title: const Text('匿名化データエクスポート'),
                  subtitle: const Text('個人情報をマスクしたJSONを出力'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportAnonymized(context),
                ),

                // 国交省提出用PDF一括出力
                ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
                  title: const Text('国交省提出用PDF一括出力'),
                  subtitle: const Text('様式1〜3をまとめたPDFを生成'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showBatchPdfDialog(context),
                ),

                // リストア
                ListTile(
                  leading: const Icon(Icons.restore, color: Colors.orange),
                  title: const Text('データを復元'),
                  subtitle: const Text('バックアップファイルからデータをインポート'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importBackup(context),
                ),

                // データリセット
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('全データを削除'),
                  subtitle: const Text('すべての飛行記録・機体・操縦者データを削除'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmDataReset(context),
                ),
                const Divider(),

                // ─── アプリ情報 ───
                const _SectionHeader(title: 'アプリケーション情報'),
                const ListTile(
                  title: Text('アプリ名'),
                  subtitle: Text(AppConstants.appName),
                ),
                const ListTile(
                  title: Text('バージョン'),
                  subtitle: Text(AppConstants.appVersion),
                ),
                const Divider(),

                // ─── 開発進捗 ───
                const _SectionHeader(title: '開発進捗'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPhaseInfo(context, AppConstants.phase1Name,
                          '機体と操縦者の基本管理機能', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, AppConstants.phase2Name,
                          '飛行記録（様式1〜3）の管理機能', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, AppConstants.phase3Name,
                          '飛行データ分析・グラフ・CSVエクスポート', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 4: スケジュール管理',
                          'Google Calendar連携・通知', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 4.5: コンプライアンス強化',
                          '写真添付・PDF読込・許可承認・編集機能', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 5: 実用性強化',
                          'ダークモード・バックアップ・テンプレート複製', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 5.5: 検索・バリデーション',
                          '飛行記録検索・ソート・入力バリデーション', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 6: ナビ再構成',
                          'マスタ管理統合・複製機能・ギャラリー・分析CSV', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 7: 安全管理',
                          '整備アラート・飛行番号・お気に入り場所・操縦者ステータス', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 8: ダッシュボード&レポート',
                          'ダッシュボード強化・様式3 PDF・月次レポート・データヘルスチェック', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 9: 効率化&一括操作',
                          '飛行時間自動計算・チェックリストテンプレート・Excelエクスポート・バッチ操作', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 10: UI/UX&通知',
                          'レスポンシブデザイン・リマインダー通知・今日のブリーフィング', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 11: データ共有&連携',
                          '提出用PDF一括出力・QRコード・サマリー共有・Excelインポート', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 12: セキュリティ&運用',
                          'PINロック・操作ログ・自動バックアップ・匿名化エクスポート', true),
                      const SizedBox(height: 12),
                      _buildPhaseInfo(context, 'Phase 13: テスト・品質保証',
                          'バリデーション強化・エラーハンドリング・オンボーディング・パフォーマンス最適化', true),
                    ],
                  ),
                ),
                const Divider(),

                // このアプリについて
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('このアプリについて'),
                  onTap: () => _showAboutDialog(context),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  /// テーマモードの日本語ラベル
  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'ライトモード';
      case ThemeMode.dark:
        return 'ダークモード';
      case ThemeMode.system:
        return 'システムに合わせる';
    }
  }

  /// テーマ選択ダイアログ
  void _showThemeSelector(BuildContext context) {
    final current = ref.read(themeModeProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('テーマを選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('ライトモード'),
              secondary: const Icon(Icons.light_mode),
              value: ThemeMode.light,
              groupValue: current,
              onChanged: (v) {
                ref.read(themeModeProvider.notifier).setThemeMode(v!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('ダークモード'),
              secondary: const Icon(Icons.dark_mode),
              value: ThemeMode.dark,
              groupValue: current,
              onChanged: (v) {
                ref.read(themeModeProvider.notifier).setThemeMode(v!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('システムに合わせる'),
              secondary: const Icon(Icons.settings_suggest),
              value: ThemeMode.system,
              groupValue: current,
              onChanged: (v) {
                ref.read(themeModeProvider.notifier).setThemeMode(v!);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// バックアップエクスポート
  Future<void> _exportBackup(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final jsonString = await BackupService.exportAllData();
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'drone_backup_$now.json';

      downloadCsvFile(jsonString, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('バックアップを保存しました: $filename'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('バックアップに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// バックアップインポート
  Future<void> _importBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        _showError('ファイルの読み込みに失敗しました');
        return;
      }

      final jsonString = utf8.decode(fileBytes);

      // 確認ダイアログ
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('データの復元'),
          content: const Text(
            '現在のデータがバックアップファイルの内容で上書きされます。\n'
            'この操作は取り消せません。続行しますか？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('復元する'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isLoading = true);
      final restoreResult = await BackupService.importAllData(jsonString);

      if (restoreResult.success) {
        // プロバイダーを再読み込み
        ref.invalidate(flightListProvider);
        ref.invalidate(inspectionListProvider);
        ref.invalidate(maintenanceListProvider);
        ref.invalidate(aircraftListProvider);
        ref.invalidate(pilotListProvider);
        await _loadDataSummary();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(restoreResult.message),
            backgroundColor: restoreResult.success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      _showError('復元に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// データリセット確認
  void _confirmDataReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('全データ削除'),
          ],
        ),
        content: const Text(
          'すべてのデータ（飛行記録、機体、操縦者、点検記録、整備記録、スケジュール）が完全に削除されます。\n\n'
          'この操作は取り消せません。\n事前にバックアップを取ることを強く推奨します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _executeDataReset();
            },
            child: const Text('全削除する'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDataReset() async {
    setState(() => _isLoading = true);
    try {
      await BackupService.clearAllData();

      // プロバイダーを再読み込み
      ref.invalidate(flightListProvider);
      ref.invalidate(inspectionListProvider);
      ref.invalidate(maintenanceListProvider);
      ref.invalidate(aircraftListProvider);
      ref.invalidate(pilotListProvider);
      await _loadDataSummary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('すべてのデータを削除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('データ削除に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Excelエクスポート
  Future<void> _exportExcel(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final flightStorageAsync = ref.read(flightLogStorageProvider);
      final localStorageAsync = ref.read(localStorageProvider);

      final flightStorage = flightStorageAsync.valueOrNull;
      final localStorage = localStorageAsync.valueOrNull;

      if (flightStorage == null || localStorage == null) {
        _showError('ストレージの読み込みに失敗しました');
        return;
      }

      final flights = await flightStorage.getAllFlights();
      final inspections = await flightStorage.getAllInspections();
      final maintenances = await flightStorage.getAllMaintenances();
      final aircrafts = localStorage.getAllAircraftsSync();
      final pilots = localStorage.getAllPilotsSync();

      final bytes = await ExcelExportService.exportAll(
        flights: flights,
        inspections: inspections,
        maintenances: maintenances,
        aircrafts: aircrafts,
        pilots: pilots,
      );

      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'drone_data_$now.xlsx';

      downloadBinaryFile(bytes, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excelファイルを保存しました: $filename'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Excelエクスポートに失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 匿名化データエクスポート
  Future<void> _exportAnonymized(BuildContext context) async {
    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.privacy_tip, color: Colors.purple),
            SizedBox(width: 8),
            Expanded(child: Text('匿名化エクスポート')),
          ],
        ),
        content: const Text(
          '操縦者名・連絡先・機体登録番号・飛行場所などの個人情報をマスクした状態でデータを出力します。\n\n'
          'デモ用やデータ分析用途に利用できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('エクスポート'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final jsonString = await AnonymizeExportService.exportAnonymized();
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'drone_anonymized_$now.json';

      downloadCsvFile(jsonString, filename);

      await AuditLogService.log(
        action: AuditAction.export_,
        target: '匿名化データ',
        detail: filename,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('匿名化データを保存しました: $filename'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('匿名化エクスポートに失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// データ整合性チェック実行
  Future<void> _runHealthCheck(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final flightStorageAsync = ref.read(flightLogStorageProvider);
      final localStorageAsync = ref.read(localStorageProvider);

      final flightStorage = flightStorageAsync.valueOrNull;
      final localStorage = localStorageAsync.valueOrNull;

      if (flightStorage == null || localStorage == null) {
        _showError('ストレージの読み込みに失敗しました');
        return;
      }

      final result = await DataHealthService.checkHealth(
        flightStorage: flightStorage,
        localStorage: localStorage,
      );

      if (!mounted) return;

      // 結果ダイアログを表示
      _showHealthCheckResult(context, result);
    } catch (e) {
      _showError('ヘルスチェックに失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ヘルスチェック結果ダイアログ
  void _showHealthCheckResult(BuildContext context, DataHealthResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.isHealthy ? Icons.check_circle : Icons.warning,
              color: result.isHealthy ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.isHealthy ? 'データは正常です' : '${result.issues.length}件の問題が見つかりました',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // サマリー
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'データサマリー',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _healthSummaryRow('飛行記録', result.summary.totalFlights),
                      _healthSummaryRow('日常点検', result.summary.totalInspections),
                      _healthSummaryRow('整備記録', result.summary.totalMaintenances),
                      _healthSummaryRow('機体', result.summary.totalAircrafts),
                      _healthSummaryRow('操縦者', result.summary.totalPilots),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 問題一覧
                if (result.issues.isNotEmpty) ...[
                  const Divider(),
                  const Text(
                    '検出された問題:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...result.issues.map((issue) {
                    Color levelColor;
                    IconData levelIcon;
                    switch (issue.level) {
                      case IssueLevel.error:
                        levelColor = Colors.red;
                        levelIcon = Icons.error;
                        break;
                      case IssueLevel.warning:
                        levelColor = Colors.orange;
                        levelIcon = Icons.warning;
                        break;
                      case IssueLevel.info:
                        levelColor = Colors.blue;
                        levelIcon = Icons.info;
                        break;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(levelIcon, size: 16, color: levelColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  issue.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: levelColor,
                                  ),
                                ),
                                Text(
                                  issue.description,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('問題は見つかりませんでした',
                          style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _healthSummaryRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text('$count件', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// 国交省提出用PDF一括出力ダイアログ（期間選択）
  void _showBatchPdfDialog(BuildContext context) {
    var startDate = DateTime.now().subtract(const Duration(days: 30));
    var endDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('提出用PDF一括出力'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('出力する期間を選択してください', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
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
                        startDate = DateTime(now.year, now.month - 3, now.day);
                        endDate = now;
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('過去1年'),
                    onPressed: () {
                      final now = DateTime.now();
                      setDialogState(() {
                        startDate = DateTime(now.year - 1, now.month, now.day);
                        endDate = now;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 開始日
              ListTile(
                dense: true,
                title: const Text('開始日', style: TextStyle(fontSize: 12)),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(startDate)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialogState(() => startDate = picked);
                },
              ),
              // 終了日
              ListTile(
                dense: true,
                title: const Text('終了日', style: TextStyle(fontSize: 12)),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(endDate)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: endDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialogState(() => endDate = picked);
                },
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
              onPressed: () {
                Navigator.pop(ctx);
                _generateBatchPdf(
                  context,
                  DateFormat('yyyy-MM-dd').format(startDate),
                  DateFormat('yyyy-MM-dd').format(endDate),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 一括PDF生成処理
  Future<void> _generateBatchPdf(BuildContext context, String startDate, String endDate) async {
    setState(() => _isLoading = true);
    try {
      final flightStorage = await ref.read(flightLogStorageProvider.future);
      final localStorage = ref.read(localStorageProvider).valueOrNull;

      if (localStorage == null) {
        _showError('ストレージの読み込みに失敗しました');
        return;
      }

      // 全データ取得
      final allFlights = await flightStorage.getAllFlights();
      final allInspections = await flightStorage.getAllInspections();
      final allMaintenances = await flightStorage.getAllMaintenances();

      // 期間フィルタ
      final flights = allFlights.where((f) =>
          f.flightDate.compareTo(startDate) >= 0 &&
          f.flightDate.compareTo(endDate) <= 0).toList();
      final inspections = allInspections.where((i) =>
          i.inspectionDate.compareTo(startDate) >= 0 &&
          i.inspectionDate.compareTo(endDate) <= 0).toList();
      final maintenances = allMaintenances.where((m) =>
          m.maintenanceDate.compareTo(startDate) >= 0 &&
          m.maintenanceDate.compareTo(endDate) <= 0).toList();

      if (flights.isEmpty && inspections.isEmpty && maintenances.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('指定期間にデータがありません'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

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

      final pdfBytes = await PdfService.generateBatchSubmissionPdf(
        flights: flights,
        inspections: inspections,
        maintenances: maintenances,
        startDate: startDate,
        endDate: endDate,
        aircraftNames: aircraftNames,
        pilotNames: pilotNames,
      );

      // PDF表示
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: '飛行日誌_${startDate}_$endDate',
        );
      }
    } catch (e) {
      _showError('PDF生成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// PIN設定ダイアログ
  void _showSetPinDialog(BuildContext context) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('PINコードを設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('4〜6桁の数字を入力してください', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PINコード',
                  hintText: '4〜6桁の数字',
                ),
              ),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PINコード（確認）',
                  hintText: 'もう一度入力',
                ),
              ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = pinController.text.trim();
                final confirm = confirmController.text.trim();
                if (pin.length < 4) {
                  setDialogState(() => errorText = '4桁以上で入力してください');
                  return;
                }
                if (pin != confirm) {
                  setDialogState(() => errorText = 'PINが一致しません');
                  return;
                }
                await AppLockService.setPin(pin);
                setState(() => _appLockEnabled = true);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('アプリロックを設定しました'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('設定'),
            ),
          ],
        ),
      ),
    );
  }

  /// PINロック解除ダイアログ
  void _showDisablePinDialog(BuildContext context) {
    final pinController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('アプリロックを解除'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('現在のPINコードを入力してください', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'PINコード'),
              ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final valid = await AppLockService.verifyPin(pinController.text.trim());
                if (valid) {
                  await AppLockService.disable();
                  setState(() => _appLockEnabled = false);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('アプリロックを解除しました'), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  setDialogState(() => errorText = 'PINが正しくありません');
                }
              },
              child: const Text('解除'),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  /// フェーズ情報を構築
  Widget _buildPhaseInfo(
    BuildContext context,
    String phase,
    String description,
    bool isCompleted,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isCompleted ? Colors.green : Colors.orange,
        ),
        borderRadius: BorderRadius.circular(8),
        color: (isCompleted ? Colors.green : Colors.orange).withOpacity(0.05),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            color: isCompleted ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phase,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// アプリケーション情報ダイアログを表示
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationLegalese: 'Copyright 2024 湊運輸倉庫株式会社',
      children: const [
        SizedBox(height: 16),
        Text('ドローン飛行日誌は、UAV（無人航空機）の飛行記録を国土交通省の様式に準拠して管理するアプリケーションです。'),
      ],
    );
  }
}

/// セクションヘッダー
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
