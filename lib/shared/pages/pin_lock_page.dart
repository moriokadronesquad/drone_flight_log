import 'package:flutter/material.dart';
import '../../core/services/app_lock_service.dart';

/// PIN入力ロック画面
/// アプリ起動時にPINコード入力を要求する
class PinLockPage extends StatefulWidget {
  final VoidCallback onUnlocked;

  const PinLockPage({super.key, required this.onUnlocked});

  @override
  State<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends State<PinLockPage> {
  String _input = '';
  String _errorMessage = '';
  bool _isVerifying = false;

  void _onKeyTap(String key) {
    if (_input.length >= 6) return;
    setState(() {
      _input += key;
      _errorMessage = '';
    });

    // 4桁以上で自動検証
    if (_input.length >= 4) {
      _verify();
    }
  }

  void _onBackspace() {
    if (_input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _errorMessage = '';
    });
  }

  Future<void> _verify() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    final valid = await AppLockService.verifyPin(_input);
    if (valid) {
      widget.onUnlocked();
    } else {
      setState(() {
        _errorMessage = 'PINが正しくありません';
        _input = '';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // アイコン
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'ドローン飛行日誌',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'PINコードを入力してください',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),

                // PIN表示ドット
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    final filled = i < _input.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: filled
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),

                // エラーメッセージ
                SizedBox(
                  height: 24,
                  child: _errorMessage.isNotEmpty
                      ? Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        )
                      : null,
                ),

                const SizedBox(height: 24),

                // テンキー
                SizedBox(
                  width: 280,
                  child: Column(
                    children: [
                      _buildKeyRow(['1', '2', '3'], isDark),
                      const SizedBox(height: 12),
                      _buildKeyRow(['4', '5', '6'], isDark),
                      const SizedBox(height: 12),
                      _buildKeyRow(['7', '8', '9'], isDark),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 空きスペース
                          const SizedBox(width: 72, height: 56),
                          // 0
                          _buildKey('0', isDark),
                          // バックスペース
                          SizedBox(
                            width: 72,
                            height: 56,
                            child: TextButton(
                              onPressed: _onBackspace,
                              child: const Icon(Icons.backspace_outlined, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildKey(k, isDark)).toList(),
    );
  }

  Widget _buildKey(String key, bool isDark) {
    return SizedBox(
      width: 72,
      height: 56,
      child: ElevatedButton(
        onPressed: () => _onKeyTap(key),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(key, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
