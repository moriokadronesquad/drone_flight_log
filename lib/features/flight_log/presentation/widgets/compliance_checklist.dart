import 'package:flutter/material.dart';

/// 航空法に基づく遵守事項チェックリスト
///
/// 飛行前に確認すべき項目をチェックリスト形式で表示する。
/// 参考: 国土交通省 無人航空機の飛行に関するルール
class ComplianceChecklist extends StatefulWidget {
  final Map<String, bool> initialChecks;
  final ValueChanged<Map<String, bool>>? onChanged;

  const ComplianceChecklist({
    super.key,
    this.initialChecks = const {},
    this.onChanged,
  });

  @override
  State<ComplianceChecklist> createState() => _ComplianceChecklistState();
}

class _ComplianceChecklistState extends State<ComplianceChecklist> {
  late Map<String, bool> _checks;

  /// 遵守事項の定義リスト
  static const List<ComplianceItem> _items = [
    ComplianceItem(
      key: 'registration',
      label: '機体登録が済んでいる',
    ),
    ComplianceItem(
      key: 'landOwnerPermit',
      label: '土地の所有者・管理者への許可取りや連絡が済んでいる',
    ),
    ComplianceItem(
      key: 'otherLawPermit',
      label: '航空法以外の法律や条例により必要な許可を取得済である',
    ),
    ComplianceItem(
      key: 'flightPlanFiled',
      label: '飛行計画を通報済である',
      hasLink: true,
    ),
    ComplianceItem(
      key: 'flightPermit',
      label: '飛行許可書や承認書を取得している',
      hasLink: true,
    ),
    ComplianceItem(
      key: 'noThirdParty',
      label: '第三者の上空ではない',
    ),
    ComplianceItem(
      key: 'noEmergencyAirspace',
      label: '緊急用務空域に指定されていない',
      hasLink: true,
    ),
    ComplianceItem(
      key: 'windSpeed',
      label: '風速が5m/s未満であり突風等のおそれが無い',
    ),
    ComplianceItem(
      key: 'noAlcohol',
      label: 'アルコールや薬物の影響がなく正常に飛行できる',
    ),
    ComplianceItem(
      key: 'noAircraft',
      label: '航行中の航空機がない',
    ),
    ComplianceItem(
      key: 'otherUavCoordinated',
      label: '他の無人航空機がある場合、飛行経路や高度について調整が済んでいる',
      hasLink: true,
    ),
    ComplianceItem(
      key: 'noSuspendedObject',
      label: '物件のつり下げ又は曳航は行わない',
    ),
    ComplianceItem(
      key: 'visibility',
      label: '十分な視程が確保できない雲や霧の中では飛行しない',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checks = Map<String, bool>.from(widget.initialChecks);
    // 未設定の項目はfalseで初期化
    for (final item in _items) {
      _checks.putIfAbsent(item.key, () => false);
    }
  }

  void _toggleItem(String key) {
    setState(() {
      _checks[key] = !(_checks[key] ?? false);
    });
    widget.onChanged?.call(Map.unmodifiable(_checks));
  }

  /// 一括登録: すべてチェック済みにする
  void _checkAll() {
    setState(() {
      for (final item in _items) {
        _checks[item.key] = true;
      }
    });
    widget.onChanged?.call(Map.unmodifiable(_checks));
  }

  /// 一括解除
  void _uncheckAll() {
    setState(() {
      for (final item in _items) {
        _checks[item.key] = false;
      }
    });
    widget.onChanged?.call(Map.unmodifiable(_checks));
  }

  int get _checkedCount => _checks.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ヘッダー + 一括登録ボタン
        Row(
          children: [
            Text(
              '$_checkedCount / ${_items.length} 項目確認済み',
              style: TextStyle(
                fontSize: 12,
                color: _checkedCount == _items.length
                    ? Colors.green[700]
                    : Colors.orange[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_checkedCount < _items.length)
              ElevatedButton(
                onPressed: _checkAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D5A80),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('一括登録'),
              )
            else
              OutlinedButton(
                onPressed: _uncheckAll,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('全解除'),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // チェックリスト
        ...List.generate(_items.length, (index) {
          final item = _items[index];
          final isChecked = _checks[item.key] ?? false;

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isChecked ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
              ),
            ),
            color: isChecked ? Colors.green[50] : null,
            child: InkWell(
              onTap: () => _toggleItem(item.key),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: isChecked ? Colors.green[800] : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.hasLink)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.link, size: 16, color: Colors.grey[400]),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isChecked ? Colors.green : const Color(0xFFBFA76A),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isChecked
                            ? Colors.green.withOpacity(0.1)
                            : const Color(0xFFFFF8E7),
                      ),
                      child: Text(
                        isChecked ? '実施済' : '未実施',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isChecked ? Colors.green[700] : const Color(0xFFBFA76A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// 遵守事項の個別項目定義
class ComplianceItem {
  final String key;
  final String label;
  final bool hasLink;

  const ComplianceItem({
    required this.key,
    required this.label,
    this.hasLink = false,
  });
}
