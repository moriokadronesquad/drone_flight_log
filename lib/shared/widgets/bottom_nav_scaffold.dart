import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'drone_icon.dart';

/// レスポンシブナビゲーション付きスキャフォルド
/// - 幅600未満: BottomNavigationBar（スマホ）
/// - 幅600以上: NavigationRail（タブレット/Web）
/// 5タブ: ホーム / 飛行記録 / 飛行予定 / マスタ管理 / 設定
class BottomNavScaffold extends StatelessWidget {
  final Widget child;
  final String currentLocation;

  const BottomNavScaffold({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  /// 現在のロケーションからタブインデックスを取得
  int _getSelectedIndex(String location) {
    if (location.startsWith('/flight-logs')) {
      return 1;
    } else if (location.startsWith('/schedule')) {
      return 2;
    } else if (location.startsWith('/master') ||
        location.startsWith('/aircrafts') ||
        location.startsWith('/pilots')) {
      return 3;
    } else if (location.startsWith('/settings')) {
      return 4;
    } else {
      return 0; // /home
    }
  }

  /// タブ選択時のナビゲーション
  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/flight-logs');
        break;
      case 2:
        context.go('/schedule');
        break;
      case 3:
        context.go('/master');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }

  /// ナビゲーション項目の定義
  static const _navItems = [
    _NavItem(icon: Icons.home, activeIcon: Icons.home_filled, label: 'ホーム'),
    _NavItem(icon: Icons.flight_takeoff, activeIcon: Icons.flight_takeoff, label: '飛行記録'),
    _NavItem(icon: Icons.calendar_month, activeIcon: Icons.calendar_month, label: '飛行予定'),
    _NavItem(icon: Icons.inventory_2, activeIcon: Icons.inventory_2, label: 'マスタ'),
    _NavItem(icon: Icons.settings, activeIcon: Icons.settings, label: '設定'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(currentLocation);
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      // タブレット / Web: サイドナビゲーション
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onTap(context, index),
              extended: MediaQuery.of(context).size.width >= 900,
              minWidth: 72,
              minExtendedWidth: 180,
              labelType: MediaQuery.of(context).size.width >= 900
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    DroneIcon(
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 4),
                    if (MediaQuery.of(context).size.width >= 900)
                      Text(
                        'ドローンログ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              destinations: _navItems
                  .map((item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.activeIcon),
                        label: Text(item.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // コンテンツ領域
            Expanded(child: child),
          ],
        ),
      );
    }

    // スマホ: BottomNavigationBar
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: selectedIndex,
        onTap: (index) => _onTap(context, index),
        items: _navItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

/// ナビゲーション項目データ
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
