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

/// 様式3：整備記録入力フォーム
class MaintenanceFormPage extends ConsumerStatefulWidget {
  final int? maintenanceId; // nullは新規、値ありは編集
  final int? copyFromId; // 複製元のID

  const MaintenanceFormPage({super.key, this.maintenanceId, this.copyFromId});

  @override
  ConsumerState<MaintenanceFormPage> createState() =>
      _MaintenanceFormPageState();
}

class _MaintenanceFormPageState extends ConsumerState<MaintenanceFormPage> {
  final _descriptionController = TextEditingController();
  final _partsReplacedController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _maintenanceDate = DateTime.now();
  DateTime? _nextMaintenanceDate;
  int? _selectedAircraftId;
  int? _selectedMaintainerId;
  String _maintenanceType = '定期点検';
  String _result = '完了';

  // 監督者
  List<int> _supervisorIds = [];
  List<String> _supervisorNames = [];

  static const _maintenanceTypes = ['定期点検', '修理', '部品交換', 'ファームウェア更新', 'その他'];
  static const _resultOptions = ['完了', '要追加整備', '不可'];

  bool get _isEditMode => widget.maintenanceId != null;
  bool _isLoadingEdit = false;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadMaintenanceData();
    } else if (widget.copyFromId != null) {
      _loadMaintenanceDataForCopy();
    } else {
      _checkDraft();
    }
    if (!_isEditMode) {
      _draftTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveDraft());
    }
  }

  /// 複製元のデータを読み込む（日付は今日にリセット、機体・整備種別・担当者を引き継ぐ）
  Future<void> _loadMaintenanceDataForCopy() async {
    setState(() => _isLoadingEdit = true);
    try {
      final maintenances = await ref.read(maintenanceListProvider.future);
      final maint = maintenances.where((m) => m.id == widget.copyFromId).firstOrNull;
      if (maint != null && mounted) {
        setState(() {
          _maintenanceDate = DateTime.now(); // 日付は今日にリセット
          _selectedAircraftId = maint.aircraftId;
          _selectedMaintainerId = maint.maintainerId;
          _maintenanceType = maint.maintenanceType;
          _descriptionController.text = ''; // 作業内容はリセット
          _partsReplacedController.text = '';
          _result = '完了'; // 結果はリセット
          _nextMaintenanceDate = null;
          _notesController.text = '';
          _supervisorIds = List.from(maint.supervisorIds);
          _supervisorNames = List.from(maint.supervisorNames);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingEdit = false);
  }

  Future<void> _checkDraft() async {
    final draft = await DraftService.loadDraft(DraftService.keyMaintenanceForm);
    if (draft != null && mounted) {
      final restore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('下書きがあります'),
          content: const Text('前回入力途中の整備データがあります。復元しますか？'),
          actions: [
            TextButton(
              onPressed: () { DraftService.clearDraft(DraftService.keyMaintenanceForm); Navigator.pop(ctx, false); },
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
      if (d['maintenanceDate'] != null) _maintenanceDate = DateTime.tryParse(d['maintenanceDate'] as String) ?? DateTime.now();
      _selectedAircraftId = d['aircraftId'] as int?;
      _selectedMaintainerId = d['maintainerId'] as int?;
      _maintenanceType = d['maintenanceType'] as String? ?? '定期点検';
      _descriptionController.text = d['description'] as String? ?? '';
      _partsReplacedController.text = d['partsReplaced'] as String? ?? '';
      _result = d['result'] as String? ?? '完了';
      _notesController.text = d['notes'] as String? ?? '';
    });
  }

  Future<void> _saveDraft() async {
    if (_isEditMode) return;
    final hasContent = _selectedAircraftId != null || _descriptionController.text.isNotEmpty;
    if (!hasContent) return;
    await DraftService.saveDraft(DraftService.keyMaintenanceForm, {
      'maintenanceDate': DateFormat('yyyy-MM-dd').format(_maintenanceDate),
      if (_selectedAircraftId != null) 'aircraftId': _selectedAircraftId,
      if (_selectedMaintainerId != null) 'maintainerId': _selectedMaintainerId,
      'maintenanceType': _maintenanceType,
      'description': _descriptionController.text,
      'partsReplaced': _partsReplacedController.text,
      'result': _result,
      'notes': _notesController.text,
    });
  }

  Future<void> _loadMaintenanceData() async {
    setState(() => _isLoadingEdit = true);
    try {
      final maintenances = await ref.read(maintenanceListProvider.future);
      final maint = maintenances.where((m) => m.id == widget.maintenanceId).firstOrNull;
      if (maint != null && mounted) {
        setState(() {
          _maintenanceDate = DateTime.tryParse(maint.maintenanceDate) ?? DateTime.now();
          _selectedAircraftId = maint.aircraftId;
          _selectedMaintainerId = maint.maintainerId;
          _maintenanceType = maint.maintenanceType;
          _descriptionController.text = maint.description ?? '';
          _partsReplacedController.text = maint.partsReplaced ?? '';
          _result = maint.result ?? '完了';
          if (maint.nextMaintenanceDate != null) {
            _nextMaintenanceDate = DateTime.tryParse(maint.nextMaintenanceDate!);
          }
          _notesController.text = maint.notes ?? '';
          _supervisorIds = List.from(maint.supervisorIds);
          _supervisorNames = List.from(maint.supervisorNames);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingEdit = false);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _descriptionController.dispose();
    _partsReplacedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool isNext}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isNext
          ? (_nextMaintenanceDate ??
              DateTime.now().add(const Duration(days: 90)))
          : _maintenanceDate,
      firstDate: isNext ? DateTime.now() : DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        if (isNext) {
          _nextMaintenanceDate = picked;
        } else {
          _maintenanceDate = picked;
        }
      });
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
      () => ValidationService.requiredSelection(_selectedAircraftId, '整備対象の機体'),
      () => ValidationService.requiredSelection(_selectedMaintainerId, '整備実施者'),
      () => ValidationService.requiredText(_descriptionController.text, '整備内容'),
    ]);
    if (errors.isNotEmpty) {
      _showError(errors.first);
      return;
    }

    final notifier = ref.read(maintenanceFormProvider.notifier);
    final date = DateFormat('yyyy-MM-dd').format(_maintenanceDate);
    final parts = _partsReplacedController.text.isEmpty
        ? null
        : _partsReplacedController.text;
    final nextDate = _nextMaintenanceDate != null
        ? DateFormat('yyyy-MM-dd').format(_nextMaintenanceDate!)
        : null;
    final notes = _notesController.text.isEmpty ? null : _notesController.text;

    if (_isEditMode) {
      await notifier.updateMaintenance(
        id: widget.maintenanceId!,
        aircraftId: _selectedAircraftId!,
        maintainerId: _selectedMaintainerId!,
        maintenanceDate: date,
        maintenanceType: _maintenanceType,
        description: _descriptionController.text,
        partsReplaced: parts,
        result: _result,
        nextMaintenanceDate: nextDate,
        notes: notes,
        supervisorIds: _supervisorIds,
        supervisorNames: _supervisorNames,
      );
    } else {
      await notifier.saveMaintenance(
        aircraftId: _selectedAircraftId!,
        maintainerId: _selectedMaintainerId!,
        maintenanceDate: date,
        maintenanceType: _maintenanceType,
        description: _descriptionController.text,
        partsReplaced: parts,
        result: _result,
        nextMaintenanceDate: nextDate,
        notes: notes,
        supervisorIds: _supervisorIds,
        supervisorNames: _supervisorNames,
      );
    }

    if (mounted && context.mounted) {
      _draftTimer?.cancel();
      DraftService.clearDraft(DraftService.keyMaintenanceForm);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? '整備記録を更新しました' : '整備記録を登録しました'),
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
    final formState = ref.watch(maintenanceFormProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '整備記録 編集' : widget.copyFromId != null ? '整備記録 複製' : '様式3：整備記録'),
        elevation: 0,
      ),
      body: _isLoadingEdit
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 整備日
            GestureDetector(
              onTap: () => _selectDate(isNext: false),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: '整備日 *'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('yyyy-MM-dd').format(_maintenanceDate)),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 整備対象機体
            aircraftsAsync.when(
              data: (aircrafts) => DropdownButtonFormField<int>(
                initialValue: _selectedAircraftId,
                decoration: const InputDecoration(labelText: '整備対象機体 *'),
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

            // 整備実施者
            pilotsAsync.when(
              data: (pilots) => DropdownButtonFormField<int>(
                initialValue: _selectedMaintainerId,
                decoration: const InputDecoration(labelText: '整備実施者 *'),
                items: pilots
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedMaintainerId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('整備者の読み込みに失敗'),
            ),
            const SizedBox(height: 12),

            // 整備種別
            DropdownButtonFormField<String>(
              initialValue: _maintenanceType,
              decoration: const InputDecoration(labelText: '整備種別 *'),
              items: _maintenanceTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _maintenanceType = v);
              },
            ),
            const SizedBox(height: 12),

            // 整備内容
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '整備内容 *',
                hintText: 'プロペラ交換、ファームウェアアップデート など',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // 交換部品
            TextFormField(
              controller: _partsReplacedController,
              decoration: const InputDecoration(
                labelText: '交換部品',
                hintText: 'プロペラ x4、バッテリー x1 など',
              ),
            ),
            const SizedBox(height: 12),

            // 整備結果
            DropdownButtonFormField<String>(
              initialValue: _result,
              decoration: const InputDecoration(labelText: '整備結果 *'),
              items: _resultOptions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _result = v);
              },
            ),
            const SizedBox(height: 12),

            // 次回整備予定日
            GestureDetector(
              onTap: () => _selectDate(isNext: true),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: '次回整備予定日'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _nextMaintenanceDate != null
                          ? DateFormat('yyyy-MM-dd')
                              .format(_nextMaintenanceDate!)
                          : '未設定',
                    ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
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
