import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/aircraft/presentation/pages/aircraft_form_page.dart';
import '../shared/pages/audit_log_page.dart';
import '../features/flight_log/presentation/pages/daily_inspection_form_page.dart';
import '../features/flight_log/presentation/pages/flight_log_page.dart';
import '../features/flight_log/presentation/pages/flight_record_form_page.dart';
import '../features/flight_log/presentation/pages/flight_record_detail_page.dart';
import '../features/flight_log/presentation/pages/inspection_detail_page.dart';
import '../features/flight_log/presentation/pages/maintenance_detail_page.dart';
import '../features/flight_log/presentation/pages/maintenance_form_page.dart';
import '../features/analytics/presentation/pages/analytics_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/schedule/presentation/pages/schedule_page.dart';
import '../features/schedule/presentation/pages/schedule_form_page.dart';
import '../features/pilot/presentation/pages/pilot_form_page.dart';
import '../features/flight_log/presentation/widgets/supervisor_selector.dart';
import '../shared/widgets/bottom_nav_scaffold.dart';
import '../shared/pages/settings_page.dart';
import '../shared/pages/master_management_page.dart';
import '../shared/pages/checklist_template_page.dart';
import '../features/sync/presentation/pages/cloud_sync_page.dart';

/// GoRouterプロバイダ
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      // シェルルート：ボトムナビゲーションバー付きのスキャフォルド
      ShellRoute(
        builder: (context, state, child) {
          return BottomNavScaffold(
            currentLocation: state.uri.path,
            child: child,
          );
        },
        routes: [
          // ホームページ
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => NoTransitionPage(
              child: HomePage(key: state.pageKey),
            ),
          ),

          // 飛行記録ページ（様式1〜3タブ）
          GoRoute(
            path: '/flight-logs',
            pageBuilder: (context, state) => NoTransitionPage(
              child: FlightLogPage(key: state.pageKey),
            ),
            routes: [
              // 様式1：飛行実績の新規登録（copyFromで複製元IDを指定可）
              GoRoute(
                path: 'flights/new',
                pageBuilder: (context, state) {
                  final copyFromStr = state.uri.queryParameters['copyFrom'];
                  final copyFromId = copyFromStr != null ? int.tryParse(copyFromStr) : null;
                  return MaterialPage(
                    child: FlightRecordFormPage(
                      key: state.pageKey,
                      copyFromId: copyFromId,
                    ),
                  );
                },
              ),
              // 様式1：飛行実績の詳細表示
              GoRoute(
                path: 'flights/:id',
                pageBuilder: (context, state) {
                  final flightId = int.parse(state.pathParameters['id']!);
                  return MaterialPage(
                    child: FlightRecordDetailPage(
                      key: state.pageKey,
                      flightId: flightId,
                    ),
                  );
                },
              ),
              // 様式1：飛行実績の編集
              GoRoute(
                path: 'flights/:id/edit',
                pageBuilder: (context, state) {
                  final flightId = int.parse(state.pathParameters['id']!);
                  return MaterialPage(
                    child: FlightRecordFormPage(
                      key: state.pageKey,
                      flightId: flightId,
                    ),
                  );
                },
              ),
              // 様式2：日常点検の新規登録（copyFromで複製元IDを指定可）
              GoRoute(
                path: 'inspections/new',
                pageBuilder: (context, state) {
                  final copyFromStr = state.uri.queryParameters['copyFrom'];
                  final copyFromId = copyFromStr != null ? int.tryParse(copyFromStr) : null;
                  return MaterialPage(
                    child: DailyInspectionFormPage(
                      key: state.pageKey,
                      copyFromId: copyFromId,
                    ),
                  );
                },
              ),
              // 様式2：日常点検の詳細表示
              GoRoute(
                path: 'inspections/:id',
                pageBuilder: (context, state) {
                  final inspId = int.parse(state.pathParameters['id']!);
                  return MaterialPage(
                    child: InspectionDetailPage(
                      key: state.pageKey,
                      inspectionId: inspId,
                    ),
                  );
                },
              ),
              // 様式2：日常点検の編集
              GoRoute(
                path: 'inspections/:id/edit',
                pageBuilder: (context, state) {
                  final inspId = int.parse(state.pathParameters['id']!);
                  return MaterialPage(
                    child: DailyInspectionFormPage(
                      key: state.pageKey,
                      inspectionId: inspId,
                    ),
                  );
                },
              ),
              // 様式3：整備記録の新規登録（copyFromで複製元IDを指定可）
              GoRoute(
                path: 'maintenances/new',
                pageBuilder: (context, state) {
                  final copyFromStr = state.uri.queryParameters['copyFrom'];
                  final copyFromId = copyFromStr != null ? int.tryParse(copyFromStr) : null;
                  return MaterialPage(
                    child: MaintenanceFormPage(
                      key: state.pageKey,
                      copyFromId: copyFromId,
                    ),
                  );
                },
              ),
              // 様式3：整備記録の詳細表示
              GoRoute(
                path: 'maintenances/:id',
                pageBuilder: (context, state) {
                  final maintId = int.parse(state.pathParameters['id']!);
                  return MaterialPage(
                    child: MaintenanceDetailPage(
                      key: state.pageKey,
                      maintenanceId: maintId,
                    ),
                  );
                },
              ),
              // 様式3：整備記録の編集
              GoRoute(
                path: 'maintenances/:id/edit',
                pageBuilder: (context, state) {
                  final maintId = int.parse(state.pathParameters['id']!);
                  return MaterialPage(
                    child: MaintenanceFormPage(
                      key: state.pageKey,
                      maintenanceId: maintId,
                    ),
                  );
                },
              ),
              // 監督者選択
              GoRoute(
                path: 'supervisor-select',
                pageBuilder: (context, state) {
                  final initialIds = state.extra as List<int>? ?? [];
                  return MaterialPage(
                    child: SupervisorSelector(
                      key: state.pageKey,
                      initialSelectedIds: initialIds,
                    ),
                  );
                },
              ),
            ],
          ),

          // マスタ管理ページ（機体＋操縦者統合）
          GoRoute(
            path: '/master',
            pageBuilder: (context, state) {
              final tabStr = state.uri.queryParameters['tab'];
              final initialTab = tabStr != null ? int.tryParse(tabStr) ?? 0 : 0;
              return NoTransitionPage(
                child: MasterManagementPage(
                  key: state.pageKey,
                  initialTab: initialTab,
                ),
              );
            },
          ),

          // 機体管理（フォーム遷移用ルート）
          GoRoute(
            path: '/aircrafts',
            redirect: (context, state) {
              // 完全一致の場合のみリダイレクト（子ルートはリダイレクトしない）
              if (state.uri.path == '/aircrafts') return '/master';
              return null;
            },
            routes: [
              // 新規機体登録
              GoRoute(
                path: 'new',
                pageBuilder: (context, state) => MaterialPage(
                  child: AircraftFormPage(key: state.pageKey),
                ),
              ),
              // 機体編集
              GoRoute(
                path: ':id/edit',
                pageBuilder: (context, state) {
                  final aircraftId = int.parse(state.pathParameters['id']!);
                  return MaterialPage(
                    child: AircraftFormPage(
                      key: state.pageKey,
                      aircraftId: aircraftId,
                    ),
                  );
                },
              ),
            ],
          ),

          // 操縦者管理（フォーム遷移用ルート）
          GoRoute(
            path: '/pilots',
            redirect: (context, state) {
              // 完全一致の場合のみリダイレクト（子ルートはリダイレクトしない）
              if (state.uri.path == '/pilots') return '/master';
              return null;
            },
            routes: [
              // 新規操縦者登録
              GoRoute(
                path: 'new',
                pageBuilder: (context, state) => MaterialPage(
                  child: PilotFormPage(key: state.pageKey),
                ),
              ),
              // 操縦者編集
              GoRoute(
                path: ':id/edit',
                pageBuilder: (context, state) {
                  final pilotId = int.parse(state.pathParameters['id']!);
                  return MaterialPage(
                    child: PilotFormPage(
                      key: state.pageKey,
                      pilotId: pilotId,
                    ),
                  );
                },
              ),
            ],
          ),

          // 飛行予定ページ（ボトムナビタブ）
          GoRoute(
            path: '/schedule',
            pageBuilder: (context, state) => NoTransitionPage(
              child: SchedulePage(key: state.pageKey),
            ),
            routes: [
              // 飛行予定の新規登録
              GoRoute(
                path: 'new',
                pageBuilder: (context, state) => MaterialPage(
                  child: ScheduleFormPage(key: state.pageKey),
                ),
              ),
            ],
          ),

          // 分析ページ
          GoRoute(
            path: '/analytics',
            pageBuilder: (context, state) => MaterialPage(
              child: AnalyticsPage(key: state.pageKey),
            ),
          ),

          // 設定ページ
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => NoTransitionPage(
              child: SettingsPage(key: state.pageKey),
            ),
          ),

          // チェックリストテンプレート管理ページ
          GoRoute(
            path: '/checklist-templates',
            pageBuilder: (context, state) => MaterialPage(
              child: ChecklistTemplatePage(key: state.pageKey),
            ),
          ),

          // クラウド同期ページ
          GoRoute(
            path: '/cloud-sync',
            pageBuilder: (context, state) => MaterialPage(
              child: CloudSyncPage(key: state.pageKey),
            ),
          ),

          // 操作ログページ
          GoRoute(
            path: '/audit-log',
            pageBuilder: (context, state) => MaterialPage(
              child: AuditLogPage(key: state.pageKey),
            ),
          ),
        ],
      ),
    ],

    // エラーページビルダー
    errorPageBuilder: (context, state) => MaterialPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('エラー')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('ページが見つかりません'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('ホームに戻る'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
