import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/draft_service.dart';
import '../../../../core/services/validation_service.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';
import '../providers/flight_log_provider.dart';
import '../widgets/supervisor_selector.dart';

/// 様式2：日常点検入力フォーム
class DailyInspectionFormPage extends ConsumerStatefulWidget {
  final int? inspectionId; // nullは新規、値ありは編集
  final int? copyFromId; // 複製元のID

  const DailyInspectionFormPage({super.key, this.inspectionId, this.copyFromId});

  @override
  ConsumerState<DailyInspectionFormPage> createState() =>
      _DailyInspectionFormPageState();
}

class _DailyInspectionFormPageState
    extends ConsumerState<DailyInspectionFormPage> {
  final _notesController = TextEditingController();

  DateTime _inspectionDate = DateTime.now();
  int? _selectedAircraftId;
  int? _selectedInspectorId;
  String _overallResult = '合格';

  // 監督者
  List<int> _supervisorIds = [];
  List<String> _supervisorNames = [];

  // 点検チェック項目
  bool _frameCheck = false;
  bool _propellerCheck = false;
  bool _motorCheck = false;
  bool _batteryCheck = false;
  bool _controllerCheck = false;
  bool _gpsCheck = false;
  bool _cameraCheck = false;
  bool _communicationCheck = false;

  static const _resultOptions = ['合格', '不合格', '要整備'];

  bool get _isEditMode => widget.inspectionId != null;
  bool _isLoadingEdit = false;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadInspectionData();
    } else if (widget.copyFromId != null) {
      _loadInspectionDataForCopy();
    } else {
      _checkDraft();
    }
    if (!_isEditMode) {
      _draftTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveDraft());
    }
  }

  /// 複製元のデータを読み込む（日付は今日にリセット、チェック項目と機体・点検者を引き継ぐ）
  Future<void> _loadInspectionDataForCopy() async {
    setState(() => _isLoadingEdit = true);
    try {
      final inspections = await ref.read(inspectionListProvider.future);
      final insp = inspections.where((i) => i.id == widget.copyFromId).firstOrNull;
      if (insp != null && mounted) {
        setState(() {
          _inspectionDate = DateTime.now(); // 日付は今日にリセット
          _selectedAircraftId = insp.aircraftId;
          _selectedInspectorId = insp.inspectorId;
          _overallResult = '合格'; // 結果はリセット
          // チェック項目は全てリセット（新しい点検なので）
          _frameCheck = false;
          _propellerCheck = false;
          _motorCheck = false;
          _batteryCheck = false;
          _controllerCheck = false;
          _gpsCheck = false;
          _cameraCheck = false;
          _communicationCheck = false;
          _notesController.text = '';
          _supervisorIds = List.from(insp.supervisorIds);
          _supervisorNames = List.from(insp.supervisorNames);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingEdit = false);
  }

  Future<void> _checkDraft() async {
    final draft = await DraftService.loadDraft(DraftService.keyInspectionForm);
    if (draft != null && mounted) {
      final restore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('下書きがあります'),
          content: const Text('前回入力途中の点検データがあります。復元しますか？'),
          actions: [
            TextButton(
              onPressed: () { DraftService.clearDraft(DraftService.keyInspectionForm); Navigator.pop(ctx, false); },
              child: const Text('破棄'),
            ),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('復元する')),
          ],
        ),
      );
      if (restore == true && mounted) _restoreDraft(draft);
    }
  }

  void _restoreDraft(Map<String, dynamic> d) {
    setState(() {
      if (d['inspectionDate'] != null) _inspectionDate = DateTime.tryParse(d['inspectionDate'] as String) ?? DateTime.now();
      _selectedAircraftId = d['aircraftId'] as int?;
      _selectedInspectorId = d['inspectorId'] as int?;
      _overallResult = d['overallResult'] as String? ?? '合格';
      _frameCheck = d['frameCheck'] as bool? ?? false;
      _propellerCheck = d['propellerCheck'] as bool? ?? false;
      _motorCheck = d['motorCheck'] as bool? ?? false;
      _batteryCheck = d['batteryCheck'] as bool? ?? false;
      _controllerCheck = d['controllerCheck'] as bool? ?? false;
      _gpsCheck = d['gpsCheck'] as bool? ?? false;
      _cameraCheck = d['cameraCheck'] as bool? ?? false;
      _communicationCheck = d['communicationCheck'] as bool? ?? false;
      _notesController.text = d['notes'] as String? ?? '';
    });
  }

  Future<void> _saveDraft() async {
    if (_isEditMode) return;
    final hasContent = _selectedAircraftId != null || _selectedInspectorId != null;
    if (!hasContent) return;
    await DraftService.saveDraft(DraftService.keyInspectionForm, {
      'inspectionDate': DateFormat('yyyy-MM-dd').format(_inspectionDate),
      if (_selectedAircraftId != null) 'aircraftId': _selectedAircraftId,
      if (_selectedInspectorId != null) 'inspectorId': _selectedInspectorId,
      'overallResult': _overallResult,
      'frameCheck': _frameCheck, 'propellerCheck': _propellerCheck,
      'motorCheck': _motorCheck, 'batteryCheck': _batteryCheck,
      'controllerCheck': _controllerCheck, 'gpsCheck': _gpsCheck,
      'cameraCheck': _cameraCheck, 'communicationCheck': _communicationCheck,
      'notes': _notesController.text,
    });
  }

  Future<void> _loadInspectionData() async {
    setState(() => _isLoadingEdit = true);
    try {
      final inspections = await ref.read(inspectionListProvider.future);
      final insp = inspections.where((i) => i.id == widget.inspectionId).firstOrNull;
      if (insp != null && mounted) {
        setState(() {
          _inspectionDate = DateTime.tryParse(insp.inspectionDate) ?? DateTime.now();
          _selectedAircraftId = insp.aircraftId;
          _selectedInspectorId = insp.inspectorId;
          _overallResult = insp.overallResult;
          _frameCheck = insp.frameCheck;
          _propellerCheck = insp.propellerCheck;
          _motorCheck = insp.motorCheck;
          _batteryCheck = insp.batteryCheck;
          _controllerCheck = insp.controllerCheck;
          _gpsCheck = insp.gpsCheck;
          _cameraCheck = insp.cameraCheck;
          _communicationCheck = insp.communicationCheck;
          _notesController.text = insp.notes ?? '';
          _supervisorIds = List.from(insp.supervisorIds);
          _supervisorNames = List.from(insp.supervisorNames);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingEdit = false);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  bool get _allChecked =>
      _frameCheck &&
      _propellerCheck &&
      _motorCheck &&
      _batteryCheck &&
      _controllerCheck &&
      _gpsCheck &&
      _cameraCheck &&
      _communicationCheck;

  void _toggleAll(bool? value) {
    final v = value ?? false;
    setState(() {
      _frameCheck = v;
      _propellerCheck = v;
      _motorCheck = v;
      _batteryCheck = v;
      _controllerCheck = v;
      _gpsCheck = v;
      _cameraCheck = v;
      _communicationCheck = v;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _inspectionDate = picked);
    }
  }

  /// 監督者選択画面を開く
  Future<void> _openSupervisorSelector() async {
    final result = await Navigator.push<SupervisorSelectionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SupervisorSelector(
          initialSelectedIds: _supervisorIds,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _supervisorIds = result.selectedPilotIds;
        _supervisorNames = result.selectedPilotNames;
      });
    }
  }

  Future<void> _submit() async {
    final errors = ValidationService.runAll([
      () => ValidationService.requiredSelection(_selectedAircraftId, '点検対象の機体'),
      () => ValidationService.requiredSelection(_selectedInspectorId, '点検者'),
    ]);
    if (errors.isNotEmpty) {
      _showError(errors.first);
      return;
    }

    final notifier = ref.read(inspectionFormProvider.notifier);
    final date = DateFormat('yyyy-MM-dd').format(_inspectionDate);
    final notes = _notesController.text.isEmpty ? null : _notesController.text;

    if (_isEditMode) {
      await notifier.updateInspection(
        id: widget.inspectionId!,
        aircraftId: _selectedAircraftId!,
        inspectorId: _selectedInspectorId!,
        inspectionDate: date,
        frameCheck: _frameCheck,
        propellerCheck: _propellerCheck,
        motorCheck: _motorCheck,
        batteryCheck: _batteryCheck,
        controllerCheck: _controllerCheck,
        gpsCheck: _gpsCheck,
        cameraCheck: _cameraCheck,
        communicationCheck: _communicationCheck,
        overallResult: _overallResult,
        notes: notes,
        supervisorIds: _supervisorIds,
        supervisorNames: _supervisorNames,
      );
    } else {
      await notifier.saveInspection(
        aircraftId: _selectedAircraftId!,
        inspectorId: _selectedInspectorId!,
        inspectionDate: date,
        frameCheck: _frameCheck,
        propellerCheck: _propellerCheck,
        motorCheck: _motorCheck,
        batteryCheck: _batteryCheck,
        controllerCheck: _controllerCheck,
        gpsCheck: _gpsCheck,
        cameraCheck: _cameraCheck,
        communicationCheck: _communicationCheck,
        overallResult: _overallResult,
        notes: notes,
        supervisorIds: _supervisorIds,
        supervisorNames: _supervisorNames,
      );
    }

    if (mounted && context.mounted) {
      _draftTimer?.cancel();
      DraftService.clearDraft(DraftService.keyInspectionForm);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? '日常点検を更新しました' : '日常点検を記録しました'),
          backgroundColor: Colors.green,
        ),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) context.pop();
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aircraftsAsync = ref.watch(aircraftListProvider);
    final pilotsAsync = ref.watch(pilotListProvider);
    final formState = ref.watch(inspectionFormProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '日常点検 編集' : widget.copyFromId != null ? '日常点検 複製' : '様式2：日常点検記録'),
        elevation: 0,
      ),
      body: _isLoadingEdit
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 点検日
            GestureDetector(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: '点検日 *'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('yyyy-MM-dd').format(_inspectionDate)),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 点検対象機体
            aircraftsAsync.when(
              data: (aircrafts) => DropdownButtonFormField<int>(
                initialValue: _selectedAircraftId,
                decoration: const InputDecoration(labelText: '点検対象機体 *'),
                items: aircrafts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            '${a.registrationNumber}'
                            '${a.modelName != null ? " (${a.modelName})" : ""}'
                            '${a.manufacturer != null ? " - ${a.manufacturer}" : ""}',
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedAircraftId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('機体の読み込みに失敗'),
            ),
            const SizedBox(height: 12),

            // 点検者
            pilotsAsync.when(
              data: (pilots) => DropdownButtonFormField<int>(
                initialValue: _selectedInspectorId,
                decoration: const InputDecoration(labelText: '点検者 *'),
                items: pilots
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedInspectorId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('点検者の読み込みに失敗'),
            ),
            const SizedBox(height: 20),

            // 点検項目チェックリスト
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '点検項目',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        TextButton(
                          onPressed: () => _toggleAll(!_allChecked),
                          child: Text(_allChecked ? '全て解除' : '全て選択'),
                        ),
                      ],
                    ),
                    const Divider(),
                    _CheckItem(
                      label: '機体（フレーム）',
                      value: _frameCheck,
                      onChanged: (v) =>
                          setState(() => _frameCheck = v ?? false),
                    ),
                    _CheckItem(
                      label: 'プロペラ',
                      value: _propellerCheck,
                      onChanged: (v) =>
                          setState(() => _propellerCheck = v ?? false),
                    ),
                    _CheckItem(
                      label: 'モーター',
                      value: _motorCheck,
                      onChanged: (v) =>
                          setState(() => _motorCheck = v ?? false),
                    ),
                    _CheckItem(
                      label: 'バッテリー',
                      value: _batteryCheck,
                      onChanged: (v) =>
                          setState(() => _batteryCheck = v ?? false),
                    ),
                    _CheckItem(
                      label: '送信機（コントローラー）',
                      value: _controllerCheck,
                      onChanged: (v) =>
                          setState(() => _controllerCheck = v ?? false),
                    ),
                    _CheckItem(
                      label: 'GPS/センサー',
                      value: _gpsCheck,
                      onChanged: (v) =>
                          setState(() => _gpsCheck = v ?? false),
                    ),
                    _CheckItem(
                      label: 'カメラ/ペイロード',
                      value: _cameraCheck,
                      onChanged: (v) =>
                          setState(() => _cameraCheck = v ?? false),
                    ),
                    _CheckItem(
                      label: '通信系統',
                      value: _communicationCheck,
                      onChanged: (v) =>
                          setState(() => _communicationCheck = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 総合判定
            DropdownButtonFormField<String>(
              initialValue: _overallResult,
              decoration: const InputDecoration(labelText: '総合判定 *'),
              items: _resultOptions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _overallResult = v);
              },
            ),
            const SizedBox(height: 12),

            // 監督者
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '監督者',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            SupervisorChips(
              supervisorNames: _supervisorNames,
              onEdit: _openSupervisorSelector,
            ),
            const SizedBox(height: 16),

            // 備考
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '備考・特記事項',
                hintText: '異常なし',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // 保存ボタン
            ElevatedButton.icon(
              onPressed: formState.isLoading ? null : _submit,
              icon: formState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

/// チェックリスト項目ウィジェット
class _CheckItem extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _CheckItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
