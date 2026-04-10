import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/local_storage.dart';
import '../../../../core/services/aircraft_safety_service.dart';
import '../../../../core/services/pilot_status_service.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';
import '../../../analytics/presentation/providers/analytics_provider.dart';
import '../../../flight_log/presentation/providers/flight_log_provider.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';
import '../../../schedule/data/schedule_storage.dart';
import '../../../schedule/presentation/providers/schedule_provider.dart';
import '../../../../shared/widgets/help_tooltip.dart';
import '../../../../shared/widgets/drone_icon.dart';

/// ホームページ
/// アプリケーションダッシュボード（Phase 8 強化版）
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aircraftListAsync = ref.watch(aircraftListProvider);
    final pilotListAsync = ref.watch(pilotListProvider);
    final flightListAsync = ref.watch(flightListProvider);
    final statsAsync = ref.watch(flightStatisticsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ドローン飛行日誌'),
        elevation: 0,
        actions: const [
          HelpTooltipButton(
            title: 'ホーム画面の使い方',
            tips: [
              '今日のブリーフィングで本日の予定と直近の点検状況を確認できます。',
              '統計カードで飛行回数・時間の概要を把握できます。',
              '下部のナビゲーションから各機能に移動できます。',
              '画面幅が広い場合は左側にナビゲーションが表示されます。',
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ウェルカムセクション ──
            _WelcomeBanner(),

            const SizedBox(height: 16),

            // ── 今日のブリーフィング ──
            _TodayBriefingCard(),

            const SizedBox(height: 16),

            // ── 今月の統計サマリー ──
            _MonthlyStatsSummary(),

            const SizedBox(height: 16),

            // ── 要対応アラート一覧 ──
            _AlertsSection(),

            const SizedBox(height: 16),

            // ── 統計情報セクション ──
            Text(
              '統計情報',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            // 機体数と操縦者数の統計カード
            Row(
              children: [
                Expanded(
                  child: aircraftListAsync.when(
                    data: (aircrafts) => _StatisticsCard(
                      title: '登録機体',
                      count: aircrafts.length,
                      icon: Icons.airplanemode_active,
                      color: Colors.blue,
                    ),
                    loading: () => const _StatisticsCard(
                      title: '登録機体', count: 0,
                      icon: Icons.airplanemode_active, color: Colors.blue, isLoading: true,
                    ),
                    error: (_, __) => const _StatisticsCard(
                      title: '登録機体', count: 0,
                      icon: Icons.airplanemode_active, color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: pilotListAsync.when(
                    data: (pilots) => _StatisticsCard(
                      title: '登録操縦者',
                      count: pilots.length,
                      icon: Icons.person,
                      color: Colors.green,
                    ),
                    loading: () => const _StatisticsCard(
                      title: '登録操縦者', count: 0,
                      icon: Icons.person, color: Colors.green, isLoading: true,
                    ),
                    error: (_, __) => const _StatisticsCard(
                      title: '登録操縦者', count: 0,
                      icon: Icons.person, color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 飛行記録数と総飛行時間
            Row(
              children: [
                Expanded(
                  child: flightListAsync.when(
                    data: (flights) => _StatisticsCard(
                      title: '飛行記録',
                      count: flights.length,
                      icon: Icons.flight_takeoff,
                      color: Colors.orange,
                    ),
                    loading: () => const _StatisticsCard(
                      title: '飛行記録', count: 0,
                      icon: Icons.flight_takeoff, color: Colors.orange, isLoading: true,
                    ),
                    error: (_, __) => const _StatisticsCard(
                      title: '飛行記録', count: 0,
                      icon: Icons.flight_takeoff, color: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: statsAsync.when(
                    data: (stats) {
                      final h = stats.totalFlightMinutes ~/ 60;
                      final m = stats.totalFlightMinutes % 60;
                      return _StatisticsCardText(
                        title: '総飛行時間',
                        value: h > 0 ? '${h}h ${m}m' : '${m}m',
                        icon: Icons.timer,
                        color: Colors.purple,
                      );
                    },
                    loading: () => const _StatisticsCardText(
                      title: '総飛行時間', value: '-',
                      icon: Icons.timer, color: Colors.purple, isLoading: true,
                    ),
                    error: (_, __) => const _StatisticsCardText(
                      title: '総飛行時間', value: '-',
                      icon: Icons.timer, color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── 最近の飛行記録 ──
            _RecentFlightsSection(),

            const SizedBox(height: 20),

            // ── 直近の飛行予定 ──
            _UpcomingScheduleCard(),

            const SizedBox(height: 20),

            // ── クイックアクションセクション ──
            Text(
              'クイックアクション',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            // 新規飛行開始ボタン
            ElevatedButton.icon(
              onPressed: () => context.push('/flight-logs/flights/new'),
              icon: const Icon(Icons.flight_takeoff),
              label: const Text('新規飛行を記録'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: 12),

            // 管理画面へのリンク（2行: 飛行記録+分析, 飛行予定+設定）
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/flight-logs'),
                    icon: const Icon(Icons.checklist),
                    label: const Text('飛行記録'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/analytics'),
                    icon: const Icon(Icons.analytics),
                    label: const Text('飛行分析'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/master'),
                    icon: const DroneIcon(size: 18, color: Colors.blue),
                    label: const Text('マスタ管理'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/schedule'),
                    icon: const Icon(Icons.event_note),
                    label: const Text('飛行予定'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // クラウド同期ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/cloud-sync'),
                icon: const Icon(Icons.cloud_sync),
                label: const Text('クラウド同期（スプレッドシート連携）'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A3A6B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// ウェルカムバナー（今日の日付と曜日付き）
class _WelcomeBanner extends StatelessWidget {
  /// DRONE PEAKブランドカラー（紫）
  static const _brandPurple = Color(0xFF4A3A6B);
  static const _brandPurpleLight = Color(0xFF6B5B8D);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy年M月d日（E）', 'ja').format(now);

    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_brandPurple, _brandPurpleLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── DRONE PEAK ロゴ部分 ───
            Row(
              children: [
                // ロゴアイコン（ドローンモチーフ）
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.flight,
                    color: _brandPurple,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                // テキストロゴ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DRONE PEAK',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                      ),
                      Text(
                        'MULTICOPTER FLIGHT SCHOOL',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              letterSpacing: 1.5,
                              fontSize: 10,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 区切り線
            Container(
              height: 1,
              color: Colors.white24,
            ),
            const SizedBox(height: 12),
            // ─── アプリ名と日付 ───
            Text(
              'ドローン飛行日誌',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 今月の飛行統計サマリー
class _MonthlyStatsSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightListAsync = ref.watch(flightListProvider);

    return flightListAsync.when(
      data: (flights) {
        final now = DateTime.now();
        final thisMonth = DateFormat('yyyy-MM').format(now);

        // 今月の飛行記録を抽出
        final monthFlights = flights.where((f) =>
          f.flightDate.startsWith(thisMonth)
        ).toList();

        final monthMinutes = monthFlights.fold<int>(
          0, (sum, f) => sum + (f.flightDuration ?? 0),
        );
        final h = monthMinutes ~/ 60;
        final m = monthMinutes % 60;

        return Card(
          color: Colors.teal.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month, size: 20, color: Colors.teal.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '今月の実績',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: '飛行回数',
                        value: '${monthFlights.length}',
                        unit: '回',
                        icon: Icons.flight,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MiniStat(
                        label: '飛行時間',
                        value: h > 0 ? '${h}h ${m}m' : '${m}m',
                        unit: '',
                        icon: Icons.timer,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// ミニ統計表示
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 28, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(unit, style: TextStyle(fontSize: 12, color: color)),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// 要対応アラートセクション
/// 全機体の安全チェック + 全操縦者の免許チェックを集約表示
class _AlertsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AlertsSection> createState() => _AlertsSectionState();
}

class _AlertsSectionState extends ConsumerState<_AlertsSection> {
  List<_AlertItem> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final storageAsync = ref.read(flightLogStorageProvider);
      final storage = storageAsync.valueOrNull;
      if (storage == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final localStorageAsync = ref.read(localStorageProvider);
      final localStorage = localStorageAsync.valueOrNull;
      if (localStorage == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final alerts = <_AlertItem>[];

      // 全機体の安全チェック
      final aircrafts = localStorage.getAllAircraftsSync();
      for (final ac in aircrafts) {
        final status = await AircraftSafetyService.checkAircraftSafety(
          aircraftId: ac.id,
          storage: storage,
        );
        if (status.safetyLevel == 'danger') {
          for (final w in status.warnings) {
            alerts.add(_AlertItem(
              level: 'danger',
              icon: Icons.airplanemode_active,
              title: ac.modelName ?? ac.registrationNumber,
              message: w,
            ));
          }
        } else if (status.safetyLevel == 'warning') {
          for (final w in status.warnings) {
            alerts.add(_AlertItem(
              level: 'warning',
              icon: Icons.airplanemode_active,
              title: ac.modelName ?? ac.registrationNumber,
              message: w,
            ));
          }
        }
      }

      // 全操縦者のステータスチェック
      final pilots = localStorage.getAllPilotsSync();
      for (final pilot in pilots) {
        final status = await PilotStatusService.checkPilotStatus(
          pilotId: pilot.id,
          storage: storage,
          licenseExpiry: pilot.licenseExpiry,
        );
        if (status.warnings.isNotEmpty) {
          for (final w in status.warnings) {
            final level = w.contains('期限切れ') || w.contains('超過')
                ? 'danger'
                : 'warning';
            alerts.add(_AlertItem(
              level: level,
              icon: Icons.person,
              title: pilot.name,
              message: w,
            ));
          }
        }
      }

      // danger を先に表示
      alerts.sort((a, b) {
        if (a.level == 'danger' && b.level != 'danger') return -1;
        if (a.level != 'danger' && b.level == 'danger') return 1;
        return 0;
      });

      if (mounted) {
        setState(() {
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_alerts.isEmpty) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'アラートはありません。すべて正常です。',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 最大5件表示
    final displayAlerts = _alerts.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, size: 20, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  '要対応アラート（${_alerts.length}件）',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...displayAlerts.map((alert) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: alert.level == 'danger' ? Colors.red : Colors.orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    alert.icon,
                    size: 18,
                    color: alert.level == 'danger' ? Colors.red : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          alert.message,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            if (_alerts.length > 5) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '他 ${_alerts.length - 5} 件',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// アラートアイテム
class _AlertItem {
  final String level; // 'danger' or 'warning'
  final IconData icon;
  final String title;
  final String message;

  const _AlertItem({
    required this.level,
    required this.icon,
    required this.title,
    required this.message,
  });
}

/// 最近の飛行記録セクション（直近5件）
class _RecentFlightsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(flightStatisticsProvider);

    return statsAsync.when(
      data: (stats) {
        if (stats.recentFlights.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近の飛行記録',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => context.go('/flight-logs'),
                  child: const Text('すべて見る'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...stats.recentFlights.map((flight) {
              final flightNo = 'FLT-${flight.id.toString().padLeft(4, '0')}';
              final duration = flight.flightDuration != null
                  ? '${flight.flightDuration}分'
                  : '-';

              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      flightNo,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  title: Text(
                    flight.takeoffLocation ?? '場所不明',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${flight.flightDate}  ${flight.takeoffTime ?? ''}-${flight.landingTime ?? ''}  $duration',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                  onTap: () => context.push('/flight-logs/flights/${flight.id}'),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// 統計情報を表示するカード（数値）
class _StatisticsCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const _StatisticsCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (isLoading)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: color, fontWeight: FontWeight.bold,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 統計情報を表示するカード（テキスト値）
class _StatisticsCardText extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const _StatisticsCardText({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (isLoading)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: color, fontWeight: FontWeight.bold,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 直近の飛行予定を表示するカード
class _UpcomingScheduleCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingScheduleProvider);

    return upcomingAsync.when(
      data: (schedules) {
        if (schedules.isEmpty) return const SizedBox.shrink();

        final displayItems = schedules.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '直近の飛行予定',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => context.go('/schedule'),
                  child: const Text('すべて見る'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: displayItems.map((schedule) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(schedule.category),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule.title,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                schedule.scheduledDate,
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'permit': return Colors.red;
      case 'plan': return Colors.blue;
      case 'log': return Colors.green;
      case 'other': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

/// 今日のブリーフィングカード
/// 今日の予定フライト・期限切れアラート・直近の点検状況をまとめて表示
class _TodayBriefingCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final upcomingAsync = ref.watch(upcomingScheduleProvider);
    final flightListAsync = ref.watch(flightListProvider);
    final inspectionListAsync = ref.watch(inspectionListProvider);

    // 今日の予定を抽出
    final todaySchedules = upcomingAsync.when(
      data: (schedules) => schedules
          .where((s) => s.scheduledDate == today && !s.isCompleted)
          .toList(),
      loading: () => <FlightScheduleData>[],
      error: (_, __) => <FlightScheduleData>[],
    );

    // 今日の飛行記録数
    final todayFlightCount = flightListAsync.when(
      data: (flights) => flights.where((f) => f.flightDate == today).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    // 最近7日間の点検件数
    final recentInspectionCount = inspectionListAsync.when(
      data: (inspections) {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        return inspections.where((i) {
          try {
            return DateTime.parse(i.inspectionDate).isAfter(weekAgo);
          } catch (_) {
            return false;
          }
        }).length;
      },
      loading: () => 0,
      error: (_, __) => 0,
    );

    // 何も表示するものがなければ非表示
    final hasContent = todaySchedules.isNotEmpty ||
        todayFlightCount > 0 ||
        recentInspectionCount > 0;

    if (!hasContent) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? Colors.blueGrey.shade800 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Icon(Icons.wb_sunny,
                    color: isDark ? Colors.amber.shade300 : Colors.orange, size: 22),
                const SizedBox(width: 8),
                Text(
                  '今日のブリーフィング',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.blue.shade900,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('M/d (E)', 'ja').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 今日の予定フライト
            if (todaySchedules.isNotEmpty)
              _BriefingItem(
                icon: Icons.calendar_today,
                iconColor: Colors.blue,
                label: '予定',
                value: '${todaySchedules.length}件',
                detail: todaySchedules.map((s) => s.title).take(2).join('、'),
              ),

            // 今日の飛行記録
            if (todayFlightCount > 0)
              _BriefingItem(
                icon: Icons.flight_takeoff,
                iconColor: Colors.green,
                label: '本日の飛行',
                value: '$todayFlightCount件記録済み',
              ),

            // 直近7日の点検状況
            _BriefingItem(
              icon: Icons.checklist,
              iconColor: recentInspectionCount > 0 ? Colors.teal : Colors.orange,
              label: '直近7日の点検',
              value: recentInspectionCount > 0
                  ? '$recentInspectionCount件実施済み'
                  : '未実施',
              detail: recentInspectionCount == 0 ? '日常点検の実施をご検討ください' : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// ブリーフィング内の1項目
class _BriefingItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? detail;

  const _BriefingItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (detail != null && detail!.isNotEmpty)
                  Text(
                    detail!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
