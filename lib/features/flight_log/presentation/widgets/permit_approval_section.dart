import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 許可承認データ（フォーム内で使用）
class PermitApprovalData {
  String? name;
  String? permitNumber;
  String? startDate;
  String? endDate;
  String? permitItems;
  String? notes;

  PermitApprovalData({
    this.name,
    this.permitNumber,
    this.startDate,
    this.endDate,
    this.permitItems,
    this.notes,
  });
}

/// 許可承認セクションウィジェット
///
/// 飛行に必要な許可承認情報を入力・表示する。
/// 参考アプリの「許可承認」セクションに対応。
class PermitApprovalSection extends StatefulWidget {
  final PermitApprovalData initialData;
  final ValueChanged<PermitApprovalData>? onChanged;

  const PermitApprovalSection({
    super.key,
    required this.initialData,
    this.onChanged,
  });

  @override
  State<PermitApprovalSection> createState() => _PermitApprovalSectionState();
}

class _PermitApprovalSectionState extends State<PermitApprovalSection> {
  late TextEditingController _nameController;
  late TextEditingController _numberController;
  late TextEditingController _notesController;
  String? _startDate;
  String? _endDate;
  String? _permitItems;

  static const List<String> _permitItemOptions = [
    'DID（人口集中地区）上空',
    '夜間飛行',
    '目視外飛行',
    '人又は物件から30m未満',
    '催し場所上空',
    '危険物の輸送',
    '物件投下',
    '150m以上の高さ',
    '空港等周辺',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData.name);
    _numberController = TextEditingController(text: widget.initialData.permitNumber);
    _notesController = TextEditingController(text: widget.initialData.notes);
    _startDate = widget.initialData.startDate;
    _endDate = widget.initialData.endDate;
    _permitItems = widget.initialData.permitItems;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged?.call(PermitApprovalData(
      name: _nameController.text.isNotEmpty ? _nameController.text : null,
      permitNumber: _numberController.text.isNotEmpty ? _numberController.text : null,
      startDate: _startDate,
      endDate: _endDate,
      permitItems: _permitItems,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    ));
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate != null ? DateTime.tryParse(_startDate!) : null) ?? now
        : (_endDate != null ? DateTime.tryParse(_endDate!) : null) ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ja'),
    );
    if (date != null) {
      setState(() {
        final formatted = DateFormat('yyyy-MM-dd').format(date);
        if (isStart) {
          _startDate = formatted;
        } else {
          _endDate = formatted;
        }
      });
      _notifyChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 名称
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '許可承認の名称',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _notifyChange(),
        ),
        const SizedBox(height: 12),

        // 許可承認番号
        TextField(
          controller: _numberController,
          decoration: const InputDecoration(
            labelText: '許可承認番号',
            hintText: '例: 東空運第○○○○号',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _notifyChange(),
        ),
        const SizedBox(height: 12),

        // 開始日付・終了日付
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickDate(true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '開始日付',
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _startDate != null
                        ? DateFormat('yyyy/M/d').format(DateTime.parse(_startDate!))
                        : '未選択',
                    style: TextStyle(
                      color: _startDate != null ? null : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _pickDate(false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '終了日付',
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _endDate != null
                        ? DateFormat('yyyy/M/d').format(DateTime.parse(_endDate!))
                        : '未選択',
                    style: TextStyle(
                      color: _endDate != null ? null : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 許可承認事項（ドロップダウン）
        DropdownButtonFormField<String>(
          initialValue: _permitItems,
          decoration: const InputDecoration(
            labelText: '許可承認事項',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('選択してください'),
            ),
            ..._permitItemOptions.map((item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 13)),
            )),
          ],
          onChanged: (value) {
            setState(() => _permitItems = value);
            _notifyChange();
          },
        ),
        const SizedBox(height: 12),

        // 備考
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: '備考',
            hintText: '直接入力',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (_) => _notifyChange(),
        ),
      ],
    );
  }
}
