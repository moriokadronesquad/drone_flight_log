import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';

/// 飛行記録フィルター結果
class FlightFilterResult {
  final int? aircraftId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool exportPdf;

  FlightFilterResult({
    this.aircraftId,
    this.startDate,
    this.endDate,
    this.exportPdf = false,
  });
}

/// 飛行記録の絞り込みダイアログ
class FlightFilterDialog extends ConsumerStatefulWidget {
  /// 現在のフィルター値（再表示時に復元するため）
  final int? initialAircraftId;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const FlightFilterDialog({
    super.key,
    this.initialAircraftId,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  ConsumerState<FlightFilterDialog> createState() => _FlightFilterDialogState();
}

class _FlightFilterDialogState extends ConsumerState<FlightFilterDialog> {
  int? _selectedAircraftId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedAircraftId = widget.initialAircraftId;
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  Widget build(BuildContext context) {
    final aircraftsAsync = ref.watch(aircraftListProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // タイトル
            Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '飛行記録の絞り込み',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 機体名ドロップダウン
            aircraftsAsync.when(
              data: (aircrafts) {
                return DropdownButtonFormField<int?>(
                  initialValue: _selectedAircraftId,
                  decoration: const InputDecoration(
                    labelText: '機体名',
                    prefixIcon: Icon(Icons.airplanemode_active),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('すべての機体'),
                    ),
                    ...aircrafts.map((a) => DropdownMenuItem<int?>(
                      value: a.id,
                      child: Text('${a.registrationNumber} - ${a.modelName}'),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedAircraftId = value;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('機体データの読み込みに失敗'),
            ),
            const SizedBox(height: 16),

            // 開始日
            _DatePickerField(
              label: '開始日',
              value: _startDate,
              onPicked: (date) {
                setState(() {
                  _startDate = date;
                });
              },
              onClear: () {
                setState(() {
                  _startDate = null;
                });
              },
            ),
            const SizedBox(height: 12),

            // 終了日
            _DatePickerField(
              label: '終了日',
              value: _endDate,
              onPicked: (date) {
                setState(() {
                  _endDate = date;
                });
              },
              onClear: () {
                setState(() {
                  _endDate = null;
                });
              },
            ),
            const SizedBox(height: 24),

            // アクションボタン
            Row(
              children: [
                // リセットボタン
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedAircraftId = null;
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('リセット'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const Spacer(),

                // 閉じるボタン
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
                const SizedBox(width: 8),

                // 絞り込み適用
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      FlightFilterResult(
                        aircraftId: _selectedAircraftId,
                        startDate: _startDate,
                        endDate: _endDate,
                      ),
                    );
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('絞り込み'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // PDF出力ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(
                    context,
                    FlightFilterResult(
                      aircraftId: _selectedAircraftId,
                      startDate: _startDate,
                      endDate: _endDate,
                      exportPdf: true,
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('国交省様式PDF出力'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 日付選択フィールド
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback onClear;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPicked,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          locale: const Locale('ja'),
        );
        if (date != null) onPicked(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          border: const OutlineInputBorder(),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : null,
        ),
        child: Text(
          value != null
              ? DateFormat('yyyy/MM/dd').format(value!)
              : '未選択',
          style: TextStyle(
            color: value != null ? null : Colors.grey,
          ),
        ),
      ),
    );
  }
}
