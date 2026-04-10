import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/local_storage.dart';
import '../../../../core/services/spreadsheet_api_service.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';

/// スプレッドシート連携ページ
class CloudSyncPage extends ConsumerStatefulWidget {
  const CloudSyncPage({super.key});

  @override
  ConsumerState<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends ConsumerState<CloudSyncPage> {
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isSyncing = false;
  String _statusMessage = '未接続';
  Map<String, dynamic>? _cloudData;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusMessage = '接続確認中...';
    });

    try {
      final connected = await SpreadsheetApiService.checkConnection();
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
        _statusMessage = connected ? '接続OK' : '接続失敗';
        _isLoading = false;
      });

      if (connected) {
        await _fetchAllData();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _statusMessage = 'エラー: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'データ取得中...';
    });

    try {
      final data = await SpreadsheetApiService.getAllData();
      if (!mounted) return;
      setState(() {
        _cloudData = data;
        _statusMessage = 'データ取得完了';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = '取得エラー: $e';
        _isLoading = false;
      });
    }
  }

  /// スプレッドシートのデータをアプリのマスタに取り込む
  Future<void> _syncToLocal({bool clearExisting = false}) async {
    if (_cloudData == null) return;

    // 先にLocalStorageの参照を取得（async gap前に）
    final localStorage = await ref.read(localStorageProvider.future);

    // クリアする場合は確認ダイアログを表示
    if (clearExisting && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('データの置き換え確認'),
          content: const Text(
            'アプリ内の機体・操縦者データをすべて削除し、\nスプレッドシートのデータで置き換えます。\n\nよろしいですか？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('置き換える', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isSyncing = true;
      _statusMessage = 'マスタデータに取り込み中...';
    });

    try {
      // 既存データをクリアする場合
      if (clearExisting) {
        await localStorage.clearAllAircrafts();
        await localStorage.clearAllPilots();
      }

      var aircraftCount = 0;
      var pilotCount = 0;

      // ─── 機体データの取り込み ───
      final aircrafts = _cloudData!['aircrafts'];
      if (aircrafts is List) {
        final existingAircrafts = await localStorage.getAllAircrafts();
        final existingRegNums = existingAircrafts
            .map((a) => a.registrationNumber)
            .toSet();

        for (final item in aircrafts) {
          final map = Map<String, dynamic>.from(item as Map);
          final regNum = map['登録番号']?.toString() ?? '';
          if (regNum.isEmpty) continue;

          if (!existingRegNums.contains(regNum)) {
            double? weight;
            final weightStr = map['最大離陸重量(kg)']?.toString() ?? '';
            if (weightStr.isNotEmpty && weightStr != '25kg超') {
              weight = double.tryParse(weightStr);
            } else if (weightStr == '25kg超') {
              weight = 25.1;
            }

            await localStorage.createAircraft(
              registrationNumber: regNum,
              aircraftType: map['機体種別']?.toString() ?? '回転翼',
              manufacturer: map['メーカー']?.toString(),
              modelName: map['型式']?.toString(),
              serialNumber: map['シリアル番号']?.toString(),
              maxTakeoffWeight: weight,
            );
            aircraftCount++;
            existingRegNums.add(regNum);
          }
        }
      }

      // ─── 操縦者データの取り込み ───
      final pilots = _cloudData!['pilots'];
      if (pilots is List) {
        final existingPilots = await localStorage.getAllPilots();
        final existingNames = existingPilots.map((p) => p.name).toSet();

        for (final item in pilots) {
          final map = Map<String, dynamic>.from(item as Map);
          final name = map['氏名']?.toString() ?? '';
          if (name.isEmpty) continue;

          if (!existingNames.contains(name)) {
            String? expiry;
            final expiryStr = map['技能証明有効期限']?.toString() ?? '';
            if (expiryStr.isNotEmpty) {
              try {
                final date = DateTime.parse(expiryStr);
                expiry = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              } catch (_) {
                expiry = expiryStr;
              }
            }

            await localStorage.createPilot(
              name: name,
              licenseNumber: map['技能証明番号']?.toString(),
              organization: map['所属']?.toString(),
              contact: map['連絡先']?.toString(),
              licenseExpiry: expiry,
            );
            pilotCount++;
            existingNames.add(name);
          }
        }
      }

      // プロバイダを更新してUIに反映（localStorageProviderも含めて全て再構築）
      if (mounted) {
        ref.invalidate(localStorageProvider);
        ref.invalidate(aircraftListProvider);
        ref.invalidate(pilotListProvider);

        setState(() {
          _isSyncing = false;
          _statusMessage = '取り込み完了！ 機体: $aircraftCount件、操縦者: $pilotCount件を追加';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('マスタデータに取り込みました（機体: $aircraftCount件、操縦者: $pilotCount件）'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _statusMessage = '取り込みエラー: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('クラウド同期'),
        backgroundColor: const Color(0xFF4A3A6B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _checkConnection,
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 12),

            if (_cloudData != null)
              _buildSyncButton(),
            const SizedBox(height: 16),

            if (_cloudData != null) ...[
              _buildDataSection(
                'ドローン機体', Icons.precision_manufacturing, Colors.green,
                _cloudData!['aircrafts'],
                ['登録番号', 'メーカー', '型式'],
              ),
              const SizedBox(height: 12),
              _buildDataSection(
                '操縦者', Icons.person, Colors.orange,
                _cloudData!['pilots'],
                ['氏名', '所属', '技能証明番号'],
              ),
              const SizedBox(height: 12),
              _buildDataSection(
                '飛行記録', Icons.description, Colors.red,
                _cloudData!['flights'],
                ['飛行日', '機体(登録番号)', '操縦者', '離陸場所'],
              ),
              const SizedBox(height: 12),
              _buildDataSection(
                '日常点検', Icons.checklist, Colors.purple,
                _cloudData!['inspections'],
                ['点検日', '機体(登録番号)', '点検者', '総合判定'],
              ),
              const SizedBox(height: 12),
              _buildDataSection(
                '整備記録', Icons.build, Colors.teal,
                _cloudData!['maintenance'],
                ['整備日', '機体(登録番号)', '整備実施者', '整備内容'],
              ),
            ],

            if (_cloudData == null && !_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'スプレッドシートに接続して\nデータを取得してください',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnected ? Colors.green : Colors.grey,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Googleスプレッドシート連携',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isLoading) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton() {
    final aircraftCount = (_cloudData!['aircrafts'] is List)
        ? (_cloudData!['aircrafts'] as List).length : 0;
    final pilotCount = (_cloudData!['pilots'] is List)
        ? (_cloudData!['pilots'] as List).length : 0;

    return Card(
      elevation: 2,
      color: const Color(0xFFF3E5F5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, color: Color(0xFF4A3A6B)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'マスタデータに取り込む',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4A3A6B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'スプレッドシート（機体$aircraftCount件・操縦者$pilotCount件）を取り込みます。',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : () => _syncToLocal(clearExisting: true),
                icon: _isSyncing
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync),
                label: Text(_isSyncing ? '取り込み中...' : '既存データを削除して置き換える'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A3A6B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSyncing ? null : () => _syncToLocal(clearExisting: false),
                icon: const Icon(Icons.add),
                label: const Text('既存データに追加する'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4A3A6B),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection(
    String title, IconData icon, Color color,
    Object? data, List<String> displayKeys,
  ) {
    final items = (data is List) ? data : [];

    return Card(
      elevation: 1,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Color.fromRGBO(color.red, color.green, color.blue, 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          '$title (${items.length}件)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('データがありません', style: TextStyle(color: Colors.grey)),
            )
          else
            ...items.map<Widget>((item) {
              final map = Map<String, dynamic>.from(item as Map);
              return ListTile(
                dense: true,
                title: Text(
                  displayKeys
                      .where((key) => map[key] != null && map[key].toString().isNotEmpty)
                      .map((key) => map[key].toString())
                      .join(' / '),
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: map.containsKey('備考') && map['備考'].toString().isNotEmpty
                    ? Text(map['備考'].toString(), style: const TextStyle(fontSize: 11))
                    : null,
              );
            }),
        ],
      ),
    );
  }
}
