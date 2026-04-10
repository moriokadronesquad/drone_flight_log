import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/app_lock_service.dart';
import 'routing/app_router.dart';
import 'shared/pages/pin_lock_page.dart';
import 'shared/pages/onboarding_page.dart';

/// アプリケーションのルートウィジェット
class DroneFlightLogApp extends ConsumerStatefulWidget {
  const DroneFlightLogApp({super.key});

  @override
  ConsumerState<DroneFlightLogApp> createState() => _DroneFlightLogAppState();
}

class _DroneFlightLogAppState extends ConsumerState<DroneFlightLogApp> {
  bool _isLocked = true;
  bool _isCheckingLock = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final lockEnabled = await AppLockService.isEnabled();
    final hasPin = await AppLockService.hasPin();
    final onboardingDone = await OnboardingPage.isCompleted();
    setState(() {
      _isLocked = lockEnabled && hasPin;
      _showOnboarding = !onboardingDone;
      _isCheckingLock = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'ドローン飛行日誌',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      home: _isCheckingLock
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isLocked
              ? PinLockPage(
                  onUnlocked: () => setState(() => _isLocked = false),
                )
              : _showOnboarding
                  ? OnboardingPage(
                      onComplete: () => setState(() => _showOnboarding = false),
                    )
                  : _RouterApp(goRouter: goRouter),
    );
  }
}

/// GoRouterを使うアプリ本体
class _RouterApp extends StatelessWidget {
  final GoRouter goRouter;
  const _RouterApp({required this.goRouter});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ドローン飛行日誌',
      theme: Theme.of(context),
      darkTheme: Theme.of(context),
      routerConfig: goRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
    );
  }
}
