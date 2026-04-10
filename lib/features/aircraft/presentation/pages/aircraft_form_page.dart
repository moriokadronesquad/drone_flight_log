import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/validation_service.dart';
import '../../domain/entities/aircraft.dart';
import '../providers/aircraft_provider.dart';

/// 航空機フォームページ
/// 新規機体の登録または既存機体の編集を行う
class AircraftFormPage extends ConsumerStatefulWidget {
  final int? aircraftId; // nullの場合は新規登録、値がある場合は編集

  const AircraftFormPage({
    super.key,
    this.aircraftId,
  });

  @override
  ConsumerState<AircraftFormPage> createState() => _AircraftFormPageState();
}

class _AircraftFormPageState extends ConsumerState<AircraftFormPage> {
  late TextEditingController _registrationNumberController;
  late TextEditingController _manufacturerController;
  late TextEditingController _modelNameController;
  late TextEditingController _serialNumberController;
  late TextEditingController _maxTakeoffWeightController;

  String _selectedAircraftType = AppConstants.aircraftTypes.first;
  Aircraft? _editingAircraft;

  @override
  void initState() {
    super.initState();
    _registrationNumberController = TextEditingController();
    _manufacturerController = TextEditingController();
    _modelNameController = TextEditingController();
    _serialNumberController = TextEditingController();
    _maxTakeoffWeightController = TextEditingController();

    // 編集モードの場合、データをロード
    if (widget.aircraftId != null) {
      _loadAircraftData();
    }
  }

  @override
  void dispose() {
    _registrationNumberController.dispose();
    _manufacturerController.dispose();
    _modelNameController.dispose();
    _serialNumberController.dispose();
    _maxTakeoffWeightController.dispose();
    super.dispose();
  }

  /// 航空機データをロード
  Future<void> _loadAircraftData() async {
    if (widget.aircraftId == null) return;

    final repository = await ref.read(aircraftRepositoryProvider.future);
    final aircraft = await repository.getAircraftById(widget.aircraftId!);

    if (aircraft != null && mounted) {
      setState(() {
        _editingAircraft = aircraft;
        _registrationNumberController.text = aircraft.registrationNumber;
        _manufacturerController.text = aircraft.manufacturer ?? '';
        _modelNameController.text = aircraft.modelName ?? '';
        _serialNumberController.text = aircraft.serialNumber ?? '';
        _maxTakeoffWeightController.text =
            aircraft.maxTakeoffWeight?.toString() ?? '';
        _selectedAircraftType = aircraft.aircraftType;
      });
    }
  }

  /// フォームを検証（ValidationService使用）
  bool _validateForm() {
    final errors = ValidationService.runAll([
      () => ValidationService.requiredText(
            _registrationNumberController.text, '登録番号'),
      () => ValidationService.registrationNumber(
            _registrationNumberController.text),
      () => ValidationService.numericRange(
            _maxTakeoffWeightController.text, '最大離陸重量',
            min: 0, max: 100),
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

    final registrationNumber = _registrationNumberController.text.toUpperCase();
    final manufacturer = _manufacturerController.text.isEmpty
        ? null
        : _manufacturerController.text;
    final modelName =
        _modelNameController.text.isEmpty ? null : _modelNameController.text;
    final serialNumber = _serialNumberController.text.isEmpty
        ? null
        : _serialNumberController.text;
    final maxTakeoffWeight = _maxTakeoffWeightController.text.isEmpty
        ? null
        : double.tryParse(_maxTakeoffWeightController.text);

    final formNotifier = ref.read(aircraftFormProvider.notifier);
    await formNotifier.saveAircraft(
      id: _editingAircraft?.id,
      registrationNumber: registrationNumber,
      aircraftType: _selectedAircraftType,
      manufacturer: manufacturer,
      modelName: modelName,
      serialNumber: serialNumber,
      maxTakeoffWeight: maxTakeoffWeight,
    );

    if (mounted && context.mounted) {
      _showSuccessSnackBar(
        _editingAircraft == null ? '機体を登録しました' : '機体を更新しました',
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          context.pop();
        }
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
    final formState = ref.watch(aircraftFormProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editingAircraft == null ? '新規機体登録' : '機体情報編集',
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
                  // 登録番号
                  TextFormField(
                    controller: _registrationNumberController,
                    decoration: const InputDecoration(
                      labelText: '登録番号 *',
                      hintText: 'JU-001',
                      prefixText: 'JU-',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),

                  // 航空機タイプ
                  DropdownButtonFormField<String>(
                    initialValue: _selectedAircraftType,
                    decoration: const InputDecoration(
                      labelText: '航空機タイプ *',
                    ),
                    items: AppConstants.aircraftTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedAircraftType = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // 製造メーカー
                  TextFormField(
                    controller: _manufacturerController,
                    decoration: const InputDecoration(
                      labelText: '製造メーカー',
                      hintText: 'DJI など',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // モデル名
                  TextFormField(
                    controller: _modelNameController,
                    decoration: const InputDecoration(
                      labelText: 'モデル名',
                      hintText: 'Mavic 3 など',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // シリアルナンバー
                  TextFormField(
                    controller: _serialNumberController,
                    decoration: const InputDecoration(
                      labelText: 'シリアルナンバー',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 最大離陸重量
                  TextFormField(
                    controller: _maxTakeoffWeightController,
                    decoration: const InputDecoration(
                      labelText: '最大離陸重量',
                      hintText: '2000 (kg)',
                      suffixText: 'kg',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                      _editingAircraft == null ? '登録' : '更新',
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
