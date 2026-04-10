import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';

/// 日常点検フィルター結果
class InspectionFilterResult {
  final int? aircraftId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool exportPdf;

  InspectionFilterResult({
    this.aircraftId,
    this.startDate,
    this.endDate,
    this.exportPdf = false,
  });
}

/// 日常点検記録の絞り込みダイアログ
class InspectionFilterDialog extends ConsumerStatefulWidget {
  final int? initialAircraftId;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const InspectionFilterDialog({
    super.key,
    this.initialAircraftId,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  ConsumerState<InspectionFilterDialog> createState() => _InspectionFilterDialogState();
}

class _InspectionFilterDialogState extends ConsumerState<InspectionFilterDialog> {
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
            Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '日常点検の絞り込み',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 20),

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

            _DateField(
              label: '開始日',
              value: _startDate,
              onPicked: (d) => setState(() => _startDate = d),
              onClear: () => setState(() => _startDate = null),
            ),
            const SizedBox(height: 12),
            _DateField(
              label: '終了日',
              value: _endDate,
              onPicked: (d) => setState(() => _endDate = d),
              onClear: () => setState(() => _endDate = null),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
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
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700]),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, InspectionFilterResult(
                      aircraftId: _selectedAircraftId,
                      startDate: _startDate,
                      endDate: _endDate,
                    ));
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('絞り込み'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, InspectionFilterResult(
                    aircraftId: _selectedAircraftId,
                    startDate: _startDate,
                    endDate: _endDate,
                    exportPdf: true,
                  ));
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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback onClear;

  const _DateField({
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
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear)
              : null,
        ),
        child: Text(
          value != null ? DateFormat('yyyy/MM/dd').format(value!) : '未選択',
          style: TextStyle(color: value != null ? null : Colors.grey),
        ),
      ),
    );
  }
}
