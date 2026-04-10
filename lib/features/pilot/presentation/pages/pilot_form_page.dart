import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/validation_service.dart';
import '../../domain/entities/pilot.dart';
import '../providers/pilot_provider.dart';

/// パイロットフォームページ
/// 新規パイロットの登録または既存パイロットの編集を行う
class PilotFormPage extends ConsumerStatefulWidget {
  final int? pilotId; // nullの場合は新規登録、値がある場合は編集

  const PilotFormPage({
    super.key,
    this.pilotId,
  });

  @override
  ConsumerState<PilotFormPage> createState() => _PilotFormPageState();
}

class _PilotFormPageState extends ConsumerState<PilotFormPage> {
  late TextEditingController _nameController;
  late TextEditingController _licenseNumberController;
  late TextEditingController _organizationController;
  late TextEditingController _contactController;
  // Phase 4.5: 技能証明書フィールド
  late TextEditingController _certificateNumberController;
  DateTime? _certificateIssueDate;
  DateTime? _certificateRegistrationDate;
  bool _autoRegister = false;

  String? _selectedLicenseType;
  DateTime? _licenseExpiryDate;
  Pilot? _editingPilot;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _licenseNumberController = TextEditingController();
    _organizationController = TextEditingController();
    _contactController = TextEditingController();
    _certificateNumberController = TextEditingController();

    // 編集モードの場合、データをロード
    if (widget.pilotId != null) {
      _loadPilotData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _licenseNumberController.dispose();
    _organizationController.dispose();
    _contactController.dispose();
    _certificateNumberController.dispose();
    super.dispose();
  }

  /// パイロットデータをロード
  Future<void> _loadPilotData() async {
    if (widget.pilotId == null) return;

    final repository = await ref.read(pilotRepositoryProvider.future);
    final pilot = await repository.getPilotById(widget.pilotId!);

    if (pilot != null && mounted) {
      setState(() {
        _editingPilot = pilot;
        _nameController.text = pilot.name;
        _licenseNumberController.text = pilot.licenseNumber ?? '';
        _selectedLicenseType = pilot.licenseType;
        if (pilot.licenseExpiry != null) {
          _licenseExpiryDate = DateTime.tryParse(pilot.licenseExpiry!);
        }
        _organizationController.text = pilot.organization ?? '';
        _contactController.text = pilot.contact ?? '';
        _certificateNumberController.text = pilot.certificateNumber ?? '';
        if (pilot.certificateIssueDate != null) {
          _certificateIssueDate = DateTime.tryParse(pilot.certificateIssueDate!);
        }
        if (pilot.certificateRegistrationDate != null) {
          _certificateRegistrationDate = DateTime.tryParse(pilot.certificateRegistrationDate!);
        }
        _autoRegister = pilot.autoRegister;
      });
    }
  }

  /// フォームを検証（ValidationService使用）
  bool _validateForm() {
    final errors = ValidationService.runAll([
      () => ValidationService.requiredText(_nameController.text, '名前'),
      () => ValidationService.maxLength(_nameController.text, '名前', 50),
    ]);

    if (errors.isNotEmpty) {
      _showErrorSnackBar(errors.first);
      return false;
    }
    return true;
  }

  /// フォームを送信
  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    final name = _nameController.text;
    final licenseNumber = _licenseNumberController.text.isEmpty
        ? null
        : _licenseNumberController.text;
    final organization = _organizationController.text.isEmpty
        ? null
        : _organizationController.text;
    final contact =
        _contactController.text.isEmpty ? null : _contactController.text;
    final licenseExpiry = _licenseExpiryDate?.toIso8601String();

    final formNotifier = ref.read(pilotFormProvider.notifier);
    await formNotifier.savePilot(
      id: _editingPilot?.id,
      name: name,
      licenseNumber: licenseNumber,
      licenseType: _selectedLicenseType,
      licenseExpiry: licenseExpiry,
      organization: organization,
      contact: contact,
      certificateNumber: _certificateNumberController.text.isNotEmpty
          ? _certificateNumberController.text : null,
      certificateIssueDate: _certificateIssueDate?.toIso8601String(),
      certificateRegistrationDate: _certificateRegistrationDate?.toIso8601String(),
      autoRegister: _autoRegister,
    );

    if (mounted && context.mounted) {
      _showSuccessSnackBar(
        _editingPilot == null ? 'パイロットを登録しました' : 'パイロット情報を更新しました',
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          context.pop();
        }
      });
    }
  }

  /// 日付ピッカーを表示
  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiryDate ?? DateTime.now().add(
        const Duration(days: 365),
      ),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 365 * 10),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _licenseExpiryDate = picked;
      });
    }
  }

  /// 成功メッセージを表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// エラーメッセージを表示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(pilotFormProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editingPilot == null ? '新規操縦者登録' : 'パイロット情報編集',
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 名前
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '名前 *',
                      hintText: '山田太郎',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 免許タイプ
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLicenseType,
                    decoration: const InputDecoration(
                      labelText: '免許種類',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('未選択'),
                      ),
                      ...AppConstants.licenseTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          ,
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedLicenseType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 免許証番号
                  TextFormField(
                    controller: _licenseNumberController,
                    decoration: const InputDecoration(
                      labelText: '免許証番号',
                      hintText: '0000000',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 免許有効期限
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '免許有効期限',
                        hintText: '選択してください',
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _licenseExpiryDate != null
                                ? DateFormat('yyyy-MM-dd').format(
                                    _licenseExpiryDate!,
                                  )
                                : '未選択',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 所属組織
                  TextFormField(
                    controller: _organizationController,
                    decoration: const InputDecoration(
                      labelText: '所属組織',
                      hintText: '湊運輸倉庫株式会社',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 連絡先
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: '連絡先',
                      hintText: '090-1234-5678',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),

                  // Phase 4.5: 技能証明書セクション
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '技能証明書情報',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 技能証明書番号
                  TextFormField(
                    controller: _certificateNumberController,
                    decoration: const InputDecoration(
                      labelText: '技能証明書番号',
                      hintText: '技能証明書番号',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 技能証明書交付日
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _certificateIssueDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('ja'),
                      );
                      if (picked != null && mounted) {
                        setState(() => _certificateIssueDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '技能証明書交付日',
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _certificateIssueDate != null
                                ? DateFormat('yyyy-MM-dd').format(_certificateIssueDate!)
                                : '未選択',
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 技能証明書登録日
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _certificateRegistrationDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('ja'),
                      );
                      if (picked != null && mounted) {
                        setState(() => _certificateRegistrationDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '技能証明書登録日',
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _certificateRegistrationDate != null
                                ? DateFormat('yyyy-MM-dd').format(_certificateRegistrationDate!)
                                : '未選択',
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 自動登録チェックボックス
                  CheckboxListTile(
                    value: _autoRegister,
                    onChanged: (v) => setState(() => _autoRegister = v ?? false),
                    title: const Text(
                      '飛行記録・日常点検・点検整備の新規作成時に自動登録',
                      style: TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),

                  // 保存ボタン
                  ElevatedButton.icon(
                    onPressed: formState.isLoading ? null : _submitForm,
                    icon: formState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _editingPilot == null ? '登録' : '更新',
                    ),
                  ),

                  if (formState.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'エラー: ${formState.error}',
                          style: TextStyle(color: Colors.red[900]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ローディングオーバーレイ
          if (formState.isLoading)
            Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
