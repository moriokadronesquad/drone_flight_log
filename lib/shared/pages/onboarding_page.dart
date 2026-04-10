import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 初回起動時に表示するオンボーディング画面
/// アプリの使い方を4ステップで説明する
class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({super.key, required this.onComplete});

  static const _storageKey = 'drone_app_onboarding_completed';

  /// オンボーディングが完了済みかチェックする
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_storageKey) ?? false;
  }

  /// オンボーディングを完了済みにする
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKey, true);
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingStep(
      icon: Icons.flight_takeoff,
      color: Colors.blue,
      title: 'ドローンログへようこそ',
      description:
          '国土交通省の様式に準拠した\nドローン飛行日誌を簡単に管理できます。\n\n飛行記録・日常点検・整備記録を\nスマホ1台で完結できます。',
    ),
    _OnboardingStep(
      icon: Icons.add_circle_outline,
      color: Colors.green,
      title: 'まずはデータを登録',
      description:
          '「マスタ管理」から\n機体と操縦者の情報を登録しましょう。\n\n登録した機体・操縦者は\n飛行記録で選択できるようになります。',
    ),
    _OnboardingStep(
      icon: Icons.edit_note,
      color: Colors.orange,
      title: '飛行記録を作成',
      description:
          '「飛行日誌」画面の＋ボタンから\n飛行記録を新規作成できます。\n\n日常点検（様式2）や整備記録（様式3）も\n同じ画面から記録できます。',
    ),
    _OnboardingStep(
      icon: Icons.picture_as_pdf,
      color: Colors.red,
      title: 'PDFで提出・共有',
      description:
          '「設定」画面から\n国交省提出用PDFを一括出力したり、\nデータのバックアップができます。\n\nさっそく始めましょう！',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // スキップボタン
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _complete,
                child: const Text('スキップ'),
              ),
            ),
            // ページ本体
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (ctx, i) => _pages[i],
              ),
            ),
            // インジケーター
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            // ボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _currentPage == _pages.length - 1
                      ? _complete
                      : () {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'はじめる' : '次へ',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete() async {
    await OnboardingPage.markCompleted();
    widget.onComplete();
  }
}

/// オンボーディングの1ステップ
class _OnboardingStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _OnboardingStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: color),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
