import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/aircraft_safety_service.dart';
import '../../../../core/services/validation_service.dart';
import '../../../../core/services/checklist_template_service.dart';
import '../../../../core/services/draft_service.dart';
import '../../../../core/services/favorite_location_service.dart';
import '../../../../core/services/pilot_status_service.dart';
import '../../../../core/services/sunrise_sunset_service.dart';
import '../../../aircraft/presentation/providers/aircraft_provider.dart';
import '../../../pilot/presentation/providers/pilot_provider.dart';
import '../providers/flight_log_provider.dart';
import '../widgets/location_picker_tab.dart';
import '../widgets/supervisor_selector.dart';
import '../widgets/compliance_checklist.dart';
import '../widgets/permit_approval_section.dart';
import '../widgets/flight_memo_section.dart';
import '../widgets/photo_attachment_section.dart';
import '../widgets/pdf_attachment_section.dart';

/// 様式1：飛行実績入力フォーム
///
/// 参考アプリの構造に合わせた展開式セクション:
/// - 遵守事項チェック
/// - 許可承認
/// - 飛行メモ（バッテリー、距離、気象条件）
/// - フライト案件
/// - 離陸/着陸時刻・場所
/// - 目的・機体・空域
/// - 監督者
class FlightRecordFormPage extends ConsumerStatefulWidget {
  final int? flightId; // nullの場合は新規作成、値がある場合は編集
  final int? copyFromId; // 複製元のID（新規作成時にデータを引き継ぐ）

  const FlightRecordFormPage({super.key, this.flightId, this.copyFromId});

  @override
  ConsumerState<FlightRecordFormPage> createState() =>
      _FlightRecordFormPageState();
}

class _FlightRecordFormPageState extends ConsumerState<FlightRecordFormPage> {
  final _takeoffLocationController = TextEditingController();
  final _landingLocationController = TextEditingController();
  final _flightPurposeController = TextEditingController();
  final _maxAltitudeController = TextEditingController();
  final _routeController = TextEditingController();

  DateTime _flightDate = DateTime.now();
  TimeOfDay? _takeoffTime;
  TimeOfDay? _landingTime;
  int? _selectedAircraftId;
  int? _selectedPilotId;
  String? _selectedFlightArea;

  // 日の出・日の入り
  SunriseSunsetData? _sunData;
  bool _isLoadingSun = false;
  String? _sunError;

  // 位置情報ピッカー展開状態
  bool _showLocationPicker = false;

  // 着陸場所 = 離陸場所と同じ
  bool _landingSameAsTakeoff = false;

  // 座標データ
  double? _takeoffLatitude;
  double? _takeoffLongitude;

  // 監督者
  List<int> _supervisorIds = [];
  List<String> _supervisorNames = [];

  // 遵守事項チェック
  Map<String, bool> _complianceChecks = {};

  // 許可承認
  PermitApprovalData _permitData = PermitApprovalData();

  // 飛行メモ
  FlightMemoData _memoData = FlightMemoData();

  // 写真添付
  List<PhotoAttachment> _photos = [];

  // PDF添付（許可承認用）
  List<PdfAttachment> _permitPdfs = [];

  // フライト前チェックリスト
  Map<String, bool> _preflightChecks = {};
  String? _selectedTemplateName;
  bool _expandPreflight = false;

  // 安全影響・不具合
  String? _safetyIncident;
  String? _defectDetail;

  // 展開状態
  bool _expandCompliance = false;
  bool _expandPermit = false;
  bool _expandMemo = false;
  bool _expandFlightConditions = false;

  static const _flightAreas = [
    'DID（人口集中地区）',
    '目視外飛行',
    '夜間飛行',
    '人・物から30m未満',
    '催し場所上空',
    '危険物輸送',
    '物件投下',
    '通常飛行',
  ];

  bool _isEditMode = false;
  bool _isLoadingEdit = false;

  // バリデーション: 送信試行後にエラー表示を有効化
  bool _showValidationErrors = false;

  // 機体安全チェック
  AircraftSafetyStatus? _safetyStatus;
  bool _isLoadingSafety = false;

  // 操縦者ステータスチェック
  PilotStatusInfo? _pilotStatus;
  bool _isLoadingPilotStatus = false;

  // ドラフト自動保存タイマー（10秒間隔）
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _fetchSunriseSunset();
    if (widget.flightId != null) {
      _isEditMode = true;
      _loadFlightData();
    } else if (widget.copyFromId != null) {
      _loadFlightDataForCopy();
    } else {
      // 新規作成時のみ: ドラフトがあれば復元を提案
      _checkDraft();
    }
    // 新規・複製時のみ自動保存（編集モードではドラフト不要）
    if (!_isEditMode) {
      _draftTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveDraft());
    }
  }

  /// ドラフトがあれば復元するか確認
  Future<void> _checkDraft() async {
    final draft = await DraftService.loadDraft(DraftService.keyFlightForm);
    if (draft != null && mounted) {
      final restore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('下書きがあります'),
          content: const Text('前回入力途中のデータがあります。復元しますか？'),
          actions: [
            TextButton(
              onPressed: () {
                DraftService.clearDraft(DraftService.keyFlightForm);
                Navigator.pop(ctx, false);
              },
              child: const Text('破棄'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('復元する'),
            ),
          ],
        ),
      );
      if (restore == true && mounted) {
        _restoreDraft(draft);
      }
    }
  }

  /// ドラフトデータからフォームを復元
  void _restoreDraft(Map<String, dynamic> draft) {
    setState(() {
      if (draft['flightDate'] != null) {
        _flightDate = DateTime.tryParse(draft['flightDate'] as String) ?? DateTime.now();
      }
      if (draft['takeoffTime'] != null) {
        final parts = (draft['takeoffTime'] as String).split(':');
        if (parts.length == 2) {
          _takeoffTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
        }
      }
      if (draft['landingTime'] != null) {
        final parts = (draft['landingTime'] as String).split(':');
        if (parts.length == 2) {
          _landingTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
        }
      }
      _selectedAircraftId = draft['aircraftId'] as int?;
      _selectedPilotId = draft['pilotId'] as int?;
      _takeoffLocationController.text = draft['takeoffLocation'] as String? ?? '';
      _landingLocationController.text = draft['landingLocation'] as String? ?? '';
      _flightPurposeController.text = draft['flightPurpose'] as String? ?? '';
      _maxAltitudeController.text = draft['maxAltitude'] as String? ?? '';
      _selectedFlightArea = draft['flightArea'] as String?;
    });
  }

  /// 現在のフォーム状態をドラフトに保存
  Future<void> _saveDraft() async {
    if (_isEditMode) return; // 編集モードではドラフト不要
    final data = <String, dynamic>{
      'flightDate': DateFormat('yyyy-MM-dd').format(_flightDate),
      if (_takeoffTime != null)
        'takeoffTime': '${_takeoffTime!.hour.toString().padLeft(2, '0')}:${_takeoffTime!.minute.toString().padLeft(2, '0')}',
      if (_landingTime != null)
        'landingTime': '${_landingTime!.hour.toString().padLeft(2, '0')}:${_landingTime!.minute.toString().padLeft(2, '0')}',
      if (_selectedAircraftId != null) 'aircraftId': _selectedAircraftId,
      if (_selectedPilotId != null) 'pilotId': _selectedPilotId,
      'takeoffLocation': _takeoffLocationController.text,
      'landingLocation': _landingLocationController.text,
      'flightPurpose': _flightPurposeController.text,
      'maxAltitude': _maxAltitudeController.text,
      if (_selectedFlightArea != null) 'flightArea': _selectedFlightArea,
    };
    // フィールドが全て空なら保存しない
    final hasContent = _selectedAircraftId != null ||
        _selectedPilotId != null ||
        _takeoffLocationController.text.isNotEmpty ||
        _flightPurposeController.text.isNotEmpty;
    if (hasContent) {
      await DraftService.saveDraft(DraftService.keyFlightForm, data);
    }
  }

  /// 複製モード：既存データをテンプレートとしてロード（日付は今日、時刻はクリア）
  Future<void> _loadFlightDataForCopy() async {
    setState(() => _isLoadingEdit = true);
    try {
      final flights = await ref.read(flightListProvider.future);
      final flight = flights.where((f) => f.id == widget.copyFromId).firstOrNull;
      if (flight != null && mounted) {
        setState(() {
          // 日付は今日にリセット、時刻はクリア（毎回異なるため）
          _flightDate = DateTime.now();
          _takeoffTime = null;
          _landingTime = null;

          // 機体・操縦者・場所・設定はコピー
          _selectedAircraftId = flight.aircraftId;
          _selectedPilotId = flight.pilotId;
          _takeoffLocationController.text = flight.takeoffLocation ?? '';
          _landingLocationController.text = flight.landingLocation ?? '';
          _flightPurposeController.text = flight.flightPurpose ?? '';
          _maxAltitudeController.text = flight.maxAltitude ?? '';
          _selectedFlightArea = flight.flightArea;
          _takeoffLatitude = flight.takeoffLatitude;
          _takeoffLongitude = flight.takeoffLongitude;
          _landingSameAsTakeoff = flight.takeoffLocation == flight.landingLocation
              && flight.takeoffLocation != null;
          _supervisorIds = List.from(flight.supervisorIds);
          _supervisorNames = List.from(flight.supervisorNames);
          _complianceChecks = Map.from(flight.complianceChecks);
          _permitData = PermitApprovalData(
            name: flight.permitName,
            permitNumber: flight.permitNumber,
            startDate: flight.permitStartDate,
            endDate: flight.permitEndDate,
            permitItems: flight.permitItems,
            notes: flight.permitNotes,
          );
          // メモは天気・バッテリーなど毎回異なるのでクリア
          _memoData = FlightMemoData();
          // 写真・PDFは複製しない（毎回異なるため）
          _photos = [];
          _permitPdfs = [];
        });
      }
    } catch (_) {
      // ロード失敗時は空フォーム
    } finally {
      if (mounted) setState(() => _isLoadingEdit = false);
    }
  }

  /// 編集モード：既存データをロード
  Future<void> _loadFlightData() async {
    setState(() => _isLoadingEdit = true);
    try {
      final flights = await ref.read(flightListProvider.future);
      final flight = flights.where((f) => f.id == widget.flightId).firstOrNull;
      if (flight != null && mounted) {
        setState(() {
          _flightDate = DateTime.tryParse(flight.flightDate) ?? DateTime.now();
          if (flight.takeoffTime != null) {
            final parts = flight.takeoffTime!.split(':');
            if (parts.length == 2) {
              _takeoffTime = TimeOfDay(
                hour: int.tryParse(parts[0]) ?? 0,
                minute: int.tryParse(parts[1]) ?? 0,
              );
            }
          }
          if (flight.landingTime != null) {
            final parts = flight.landingTime!.split(':');
            if (parts.length == 2) {
              _landingTime = TimeOfDay(
                hour: int.tryParse(parts[0]) ?? 0,
                minute: int.tryParse(parts[1]) ?? 0,
              );
            }
          }
          _selectedAircraftId = flight.aircraftId;
          _selectedPilotId = flight.pilotId;
          _takeoffLocationController.text = flight.takeoffLocation ?? '';
          _landingLocationController.text = flight.landingLocation ?? '';
          _flightPurposeController.text = flight.flightPurpose ?? '';
          _maxAltitudeController.text = flight.maxAltitude ?? '';
          _routeController.text = '';
          _selectedFlightArea = flight.flightArea;
          _takeoffLatitude = flight.takeoffLatitude;
          _takeoffLongitude = flight.takeoffLongitude;
          _landingSameAsTakeoff = flight.takeoffLocation == flight.landingLocation
              && flight.takeoffLocation != null;
          _supervisorIds = List.from(flight.supervisorIds);
          _supervisorNames = List.from(flight.supervisorNames);
          _complianceChecks = Map.from(flight.complianceChecks);
          _permitData = PermitApprovalData(
            name: flight.permitName,
            permitNumber: flight.permitNumber,
            startDate: flight.permitStartDate,
            endDate: flight.permitEndDate,
            permitItems: flight.permitItems,
            notes: flight.permitNotes,
          );
          _memoData = FlightMemoData(
            weather: flight.weather,
            windSpeed: flight.windSpeed,
            temperature: flight.temperature,
            batteryBefore: flight.batteryBefore,
            batteryAfter: flight.batteryAfter,
            batteryNumber: flight.batteryNumber,
            flightDistance: flight.flightDistance,
            ownerConsent: flight.ownerConsent,
            notes: flight.notes,
          );
          _safetyIncident = flight.safetyIncident;
          _defectDetail = flight.defectDetail;
          // 写真データの復元
          _photos = flight.photoAttachments.map((p) {
            try {
              return PhotoAttachment.fromBase64(p['name'] ?? 'photo', p['data'] ?? '');
            } catch (_) {
              return null;
            }
          }).whereType<PhotoAttachment>().toList();
          // PDFデータの復元
          _permitPdfs = flight.pdfAttachments.map((p) {
            try {
              return PdfAttachment.fromBase64(p['name'] ?? 'doc.pdf', p['data'] ?? '');
            } catch (_) {
              return null;
            }
          }).whereType<PdfAttachment>().toList();
        });
      }
    } catch (_) {
      // データロードエラー時は空フォームのまま
    } finally {
      if (mounted) {
        setState(() => _isLoadingEdit = false);
        // 機体が選択されていれば安全チェックも実行
        if (_selectedAircraftId != null) _checkAircraftSafety(_selectedAircraftId!);
      }
    }
  }

  Future<void> _fetchSunriseSunset() async {
    setState(() { _isLoadingSun = true; _sunError = null; });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_flightDate);
      final data = await SunriseSunsetService.getSunriseSunset(date: dateStr);
      if (mounted) {
        setState(() {
          _sunData = data;
          _isLoadingSun = false;
          if (data == null) _sunError = '取得できませんでした';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoadingSun = false; _sunError = '通信エラー'; });
      }
    }
  }

  /// 機体の安全チェックを実行
  Future<void> _checkAircraftSafety(int aircraftId) async {
    setState(() => _isLoadingSafety = true);
    try {
      final storage = await ref.read(flightLogStorageProvider.future);
      final status = await AircraftSafetyService.checkAircraftSafety(
        aircraftId: aircraftId,
        storage: storage,
      );
      if (mounted) {
        setState(() {
          _safetyStatus = status;
          _isLoadingSafety = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSafety = false);
    }
  }

  /// 操縦者のステータスチェックを実行
  Future<void> _checkPilotStatus(int pilotId) async {
    setState(() => _isLoadingPilotStatus = true);
    try {
      // 操縦者の免許有効期限を取得
      final pilots = await ref.read(pilotListProvider.future);
      final pilot = pilots.where((p) => p.id == pilotId).firstOrNull;
      final storage = await ref.read(flightLogStorageProvider.future);
      final status = await PilotStatusService.checkPilotStatus(
        pilotId: pilotId,
        licenseExpiry: pilot?.licenseExpiry,
        storage: storage,
      );
      if (mounted) {
        setState(() {
          _pilotStatus = status;
          _isLoadingPilotStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPilotStatus = false);
    }
  }

  /// お気に入り場所一覧ダイアログを表示
  Future<void> _showFavoriteLocations() async {
    final favorites = await FavoriteLocationService.getAll();

    if (!mounted) return;

    if (favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('お気に入り場所がまだ登録されていません。\n住所入力後、☆ボタンで登録できます'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final selected = await showDialog<FavoriteLocation>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('お気に入り場所'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final loc = favorites[index];
              return ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text(loc.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(loc.address, style: const TextStyle(fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  onPressed: () async {
                    await FavoriteLocationService.remove(loc.address);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showFavoriteLocations(); // 再表示
                  },
                ),
                onTap: () => Navigator.pop(ctx, loc),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _takeoffLocationController.text = selected.address;
        _takeoffLatitude = selected.latitude;
        _takeoffLongitude = selected.longitude;
      });
      await FavoriteLocationService.recordUse(selected.address);
    }
  }

  /// 現在入力中の住所をお気に入りに追加
  Future<void> _addCurrentLocationToFavorites() async {
    final address = _takeoffLocationController.text.trim();
    if (address.isEmpty) return;

    // 場所名を入力してもらうダイアログ
    final nameController = TextEditingController(text: address.length > 20 ? address.substring(0, 20) : address);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('お気に入りに追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('場所: $address', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '場所の名前（短い名前）',
                hintText: '例：○○河川敷、△△公園',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: const Text('登録'),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (name != null && name.isNotEmpty && mounted) {
      await FavoriteLocationService.add(FavoriteLocation(
        name: name,
        address: address,
        latitude: _takeoffLatitude,
        longitude: _takeoffLongitude,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$name」をお気に入りに追加しました'), backgroundColor: Colors.green),
        );
      }
    }
  }

  /// フライト前チェックリストセクションを構築
  Widget _buildPreflightChecklistSection() {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // テンプレート選択ボタン
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.format_list_bulleted, size: 16),
                    label: Text(
                      _selectedTemplateName ?? 'テンプレートを選択',
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: _selectChecklistTemplate,
                  ),
                ),
                if (_preflightChecks.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'チェックリストをクリア',
                    onPressed: () {
                      setState(() {
                        _preflightChecks.clear();
                        _selectedTemplateName = null;
                      });
                    },
                  ),
                ],
              ],
            ),
            // チェック項目表示
            if (_preflightChecks.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._preflightChecks.entries.toList().asMap().entries.map((entry) {
                final item = entry.value;
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    item.key,
                    style: TextStyle(
                      fontSize: 13,
                      decoration: item.value ? TextDecoration.lineThrough : null,
                      color: item.value ? Colors.grey : null,
                    ),
                  ),
                  value: item.value,
                  onChanged: (v) {
                    setState(() {
                      _preflightChecks[item.key] = v ?? false;
                    });
                  },
                );
              }),
              // 全チェック / 全クリアボタン
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final key in _preflightChecks.keys) {
                          _preflightChecks[key] = true;
                        }
                      });
                    },
                    child: const Text('全てチェック', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final key in _preflightChecks.keys) {
                          _preflightChecks[key] = false;
                        }
                      });
                    },
                    child: const Text('全てクリア', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// チェックリストテンプレート選択ダイアログ
  Future<void> _selectChecklistTemplate() async {
    final templates = await ChecklistTemplateService.getAll();

    if (!mounted) return;

    final selected = await showDialog<ChecklistTemplate>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('テンプレートを選択'),
        children: [
          if (templates.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('テンプレートがありません')),
            ),
          ...templates.map((t) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, t),
            child: ListTile(
              leading: Icon(Icons.checklist, color: Colors.blue.shade700),
              title: Text(t.name),
              subtitle: Text('${t.items.length}項目', style: const TextStyle(fontSize: 12)),
              dense: true,
            ),
          )),
        ],
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedTemplateName = selected.name;
        _preflightChecks = {
          for (final item in selected.items) item: false,
        };
      });
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _takeoffLocationController.dispose();
    _landingLocationController.dispose();
    _flightPurposeController.dispose();
    _maxAltitudeController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  /// 飛行時間の手動上書き値（nullの場合は自動計算）
  int? _manualDurationOverride;
  bool _isDurationManual = false;

  Future<void> _selectTime({required bool isTakeoff}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isTakeoff
          ? (_takeoffTime ?? TimeOfDay.now())
          : (_landingTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isTakeoff) {
          _takeoffTime = picked;
        } else {
          _landingTime = picked;
        }
        // 時刻変更時、手動上書きでなければ自動計算に戻す
        if (!_isDurationManual) {
          _manualDurationOverride = null;
        }
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// 飛行時間を算出（手動上書きがあればそちらを優先）
  int? _calcDuration() {
    if (_isDurationManual && _manualDurationOverride != null) {
      return _manualDurationOverride;
    }
    if (_takeoffTime == null || _landingTime == null) return null;
    final start = _takeoffTime!.hour * 60 + _takeoffTime!.minute;
    final end = _landingTime!.hour * 60 + _landingTime!.minute;
    return end - start > 0 ? end - start : null;
  }

  /// 飛行時間の手動入力ダイアログ
  Future<void> _showDurationEditor() async {
    final autoDuration = _calcAutoDuration();
    final currentValue = _isDurationManual
        ? _manualDurationOverride
        : autoDuration;

    final controller = TextEditingController(
      text: currentValue?.toString() ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('飛行時間の設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (autoDuration != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '自動計算: $autoDuration分（${autoDuration ~/ 60}h ${autoDuration % 60}m）',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '飛行時間（分）',
                  hintText: '例: 30',
                  suffixText: '分',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            if (autoDuration != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, {'mode': 'auto'}),
                child: const Text('自動計算に戻す'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text);
                Navigator.pop(ctx, {'mode': 'manual', 'value': val});
              },
              child: const Text('設定'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    setState(() {
      if (result['mode'] == 'auto') {
        _isDurationManual = false;
        _manualDurationOverride = null;
      } else if (result['mode'] == 'manual' && result['value'] != null) {
        _isDurationManual = true;
        _manualDurationOverride = result['value'] as int;
      }
    });
  }

  /// 自動計算値のみを取得（手動上書きを無視）
  int? _calcAutoDuration() {
    if (_takeoffTime == null || _landingTime == null) return null;
    final start = _takeoffTime!.hour * 60 + _takeoffTime!.minute;
    final end = _landingTime!.hour * 60 + _landingTime!.minute;
    return end - start > 0 ? end - start : null;
  }

  Future<void> _openSupervisorSelector() async {
    final result = await Navigator.push<SupervisorSelectionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SupervisorSelector(initialSelectedIds: _supervisorIds),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _supervisorIds = result.selectedPilotIds;
        _supervisorNames = result.selectedPilotNames;
      });
    }
  }

  /// テキスト入力ダイアログを表示し、入力結果を返す
  Future<String?> _showTextInputDialog({
    required String title,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '内容を入力してください',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          if (initialValue != null && initialValue.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('クリア', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('登録'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _submit() async {
    // バリデーションエラー表示を有効化
    setState(() => _showValidationErrors = true);

    // ValidationServiceを使った一括バリデーション
    final takeoffStr = _takeoffTime != null ? _formatTime(_takeoffTime) : null;
    final landingStr = _landingTime != null ? _formatTime(_landingTime) : null;

    final errors = ValidationService.runAll([
      () => ValidationService.requiredSelection(_selectedAircraftId, '使用機体'),
      () => ValidationService.requiredSelection(_selectedPilotId, '操縦者'),
      () => ValidationService.timeAfter(takeoffStr, landingStr, '離陸時刻', '着陸時刻'),
      () => ValidationService.numericRange(
            _maxAltitudeController.text, '最大高度',
            min: 0, max: 500),
    ]);

    if (errors.isNotEmpty) {
      _showError('入力エラー: ${errors.join('、')}');
      return;
    }

    final landingLoc = _landingSameAsTakeoff
        ? _takeoffLocationController.text
        : _landingLocationController.text;

    final notifier = ref.read(flightFormProvider.notifier);

    // 共通パラメータ
    final flightDate = DateFormat('yyyy-MM-dd').format(_flightDate);
    final takeoffTime = _takeoffTime != null ? _formatTime(_takeoffTime) : null;
    final landingTime = _landingTime != null ? _formatTime(_landingTime) : null;
    final photoData = _photos
        .map((p) => {'name': p.name, 'data': p.toBase64()})
        .toList();
    final pdfData = _permitPdfs
        .map((p) => {'name': p.name, 'data': p.toBase64()})
        .toList();

    if (_isEditMode && widget.flightId != null) {
      // 更新
      await notifier.updateFlight(
        id: widget.flightId!,
        aircraftId: _selectedAircraftId!,
        pilotId: _selectedPilotId!,
        flightDate: flightDate,
        takeoffTime: takeoffTime,
        landingTime: landingTime,
        flightDuration: _calcDuration(),
        takeoffLocation: _takeoffLocationController.text.isEmpty
            ? null : _takeoffLocationController.text,
        landingLocation: landingLoc.isEmpty ? null : landingLoc,
        flightPurpose: _flightPurposeController.text.isEmpty
            ? null : _flightPurposeController.text,
        flightArea: _selectedFlightArea,
        maxAltitude: _maxAltitudeController.text.isEmpty
            ? null : _maxAltitudeController.text,
        weather: _memoData.weather,
        windSpeed: _memoData.windSpeed,
        temperature: _memoData.temperature,
        notes: _memoData.notes,
        supervisorIds: _supervisorIds,
        supervisorNames: _supervisorNames,
        batteryBefore: _memoData.batteryBefore,
        batteryAfter: _memoData.batteryAfter,
        batteryNumber: _memoData.batteryNumber,
        flightDistance: _memoData.flightDistance,
        ownerConsent: _memoData.ownerConsent,
        takeoffLatitude: _takeoffLatitude,
        takeoffLongitude: _takeoffLongitude,
        complianceChecks: _complianceChecks,
        permitName: _permitData.name,
        permitNumber: _permitData.permitNumber,
        permitStartDate: _permitData.startDate,
        permitEndDate: _permitData.endDate,
        permitItems: _permitData.permitItems,
        permitNotes: _permitData.notes,
        safetyIncident: _safetyIncident,
        defectDetail: _defectDetail,
        photoAttachments: photoData,
        pdfAttachments: pdfData,
      );
    } else {
      // 新規作成
      await notifier.saveFlight(
        aircraftId: _selectedAircraftId!,
        pilotId: _selectedPilotId!,
        flightDate: flightDate,
        takeoffTime: takeoffTime,
        landingTime: landingTime,
        flightDuration: _calcDuration(),
        takeoffLocation: _takeoffLocationController.text.isEmpty
            ? null : _takeoffLocationController.text,
        landingLocation: landingLoc.isEmpty ? null : landingLoc,
        flightPurpose: _flightPurposeController.text.isEmpty
            ? null : _flightPurposeController.text,
        flightArea: _selectedFlightArea,
        maxAltitude: _maxAltitudeController.text.isEmpty
            ? null : _maxAltitudeController.text,
        weather: _memoData.weather,
        windSpeed: _memoData.windSpeed,
        temperature: _memoData.temperature,
        notes: _memoData.notes,
        supervisorIds: _supervisorIds,
        supervisorNames: _supervisorNames,
        batteryBefore: _memoData.batteryBefore,
        batteryAfter: _memoData.batteryAfter,
        batteryNumber: _memoData.batteryNumber,
        flightDistance: _memoData.flightDistance,
        ownerConsent: _memoData.ownerConsent,
        takeoffLatitude: _takeoffLatitude,
        takeoffLongitude: _takeoffLongitude,
        complianceChecks: _complianceChecks,
        permitName: _permitData.name,
        permitNumber: _permitData.permitNumber,
        permitStartDate: _permitData.startDate,
        permitEndDate: _permitData.endDate,
        permitItems: _permitData.permitItems,
        permitNotes: _permitData.notes,
        safetyIncident: _safetyIncident,
        defectDetail: _defectDetail,
        photoAttachments: photoData,
        pdfAttachments: pdfData,
      );
    }

    if (mounted && context.mounted) {
      // 保存成功時にドラフトを削除
      _draftTimer?.cancel();
      DraftService.clearDraft(DraftService.keyFlightForm);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? '飛行記録を更新しました' : '飛行実績を記録しました'),
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

  /// 展開式セクションヘッダーを構築
  Widget _buildExpandableHeader({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    IconData? infoIcon,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (infoIcon != null) ...[
              const SizedBox(width: 6),
              Icon(infoIcon, size: 16, color: Colors.grey),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
            const Spacer(),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aircraftsAsync = ref.watch(aircraftListProvider);
    final pilotsAsync = ref.watch(pilotListProvider);
    final formState = ref.watch(flightFormProvider);
    final duration = _calcDuration();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '飛行記録 編集' : widget.copyFromId != null ? '飛行記録 複製' : '飛行記録'),
        elevation: 0,
      ),
      body: _isLoadingEdit
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== 写真添付 =====
            PhotoAttachmentSection(
              initialPhotos: _photos,
              onChanged: (photos) => _photos = photos,
            ),
            const SizedBox(height: 12),

            // ===== フライト前チェックリスト =====
            _buildExpandableHeader(
              title: 'フライト前チェック',
              expanded: _expandPreflight,
              infoIcon: Icons.playlist_add_check,
              trailing: _preflightChecks.isNotEmpty
                  ? _PreflightBadge(checks: _preflightChecks)
                  : null,
              onTap: () => setState(() => _expandPreflight = !_expandPreflight),
            ),
            if (_expandPreflight) ...[
              const SizedBox(height: 8),
              _buildPreflightChecklistSection(),
            ],
            const SizedBox(height: 12),

            // ===== 遵守事項チェック =====
            _buildExpandableHeader(
              title: '遵守事項チェック',
              expanded: _expandCompliance,
              infoIcon: Icons.info_outline,
              trailing: _complianceChecks.isNotEmpty
                  ? _ComplianceBadge(checks: _complianceChecks)
                  : null,
              onTap: () => setState(() => _expandCompliance = !_expandCompliance),
            ),
            if (_expandCompliance)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ComplianceChecklist(
                  initialChecks: _complianceChecks,
                  onChanged: (checks) => _complianceChecks = checks,
                ),
              ),
            const SizedBox(height: 8),

            // ===== 許可承認 =====
            _buildExpandableHeader(
              title: '許可承認',
              expanded: _expandPermit,
              infoIcon: Icons.info_outline,
              onTap: () => setState(() => _expandPermit = !_expandPermit),
            ),
            if (_expandPermit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    PermitApprovalSection(
                      initialData: _permitData,
                      onChanged: (data) => _permitData = data,
                    ),
                    const SizedBox(height: 12),
                    // PDF添付（飛行許可書のインポート）
                    PdfAttachmentSection(
                      initialPdfs: _permitPdfs,
                      onChanged: (pdfs) => _permitPdfs = pdfs,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // ===== 飛行メモ =====
            _buildExpandableHeader(
              title: '飛行メモ',
              expanded: _expandMemo,
              infoIcon: Icons.info_outline,
              onTap: () => setState(() => _expandMemo = !_expandMemo),
            ),
            if (_expandMemo)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FlightMemoSection(
                  initialData: _memoData,
                  onChanged: (data) => _memoData = data,
                ),
              ),
            const SizedBox(height: 8),

            // ===== フライト案件（飛行条件） =====
            _buildExpandableHeader(
              title: 'フライト案件',
              expanded: _expandFlightConditions,
              infoIcon: Icons.info_outline,
              onTap: () => setState(() => _expandFlightConditions = !_expandFlightConditions),
            ),
            if (_expandFlightConditions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _flightPurposeController,
                      decoration: const InputDecoration(
                        labelText: '飛行目的',
                        hintText: '空撮、測量、点検 など',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedFlightArea,
                      decoration: const InputDecoration(
                        labelText: '飛行空域・方法',
                        border: OutlineInputBorder(),
                      ),
                      items: _flightAreas
                          .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedFlightArea = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _maxAltitudeController,
                      decoration: const InputDecoration(
                        labelText: '最大高度',
                        hintText: '150',
                        suffixText: 'm',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _routeController,
                      decoration: const InputDecoration(
                        labelText: '経路・経由地等',
                        hintText: '直接入力',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // ===== 離陸・着陸時刻 =====
            Card(
              elevation: 0,
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // 離陸時刻
                    Row(
                      children: [
                        const SizedBox(
                          width: 80,
                          child: Text('離陸時刻', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(isTakeoff: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${DateFormat('M/d').format(_flightDate)} ${_formatTime(_takeoffTime)}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.expand_more, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    // 着陸時刻
                    Row(
                      children: [
                        const SizedBox(
                          width: 80,
                          child: Text('着陸時刻', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(isTakeoff: false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${DateFormat('M/d').format(_flightDate)} ${_formatTime(_landingTime)}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.expand_more, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    // 滞空時間（タップで手動入力可能）
                    InkWell(
                      onTap: _showDurationEditor,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('滞空時間', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                if (_isDurationManual)
                                  Text('手動', style: TextStyle(fontSize: 10, color: Colors.orange.shade700))
                                else if (duration != null)
                                  Text('自動計算', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isDurationManual
                                    ? Colors.orange.withOpacity(0.5)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(4),
                              color: _isDurationManual
                                  ? Colors.orange.shade50
                                  : null,
                            ),
                            child: Text(
                              '${duration ?? 0}',
                              style: TextStyle(
                                fontSize: 16,
                                color: _isDurationManual ? Colors.orange.shade800 : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('分', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit, size: 14, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 飛行時間サマリー表示
            if (duration != null && duration > 0) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '飛行時間: ${duration ~/ 60} 時間 ${duration % 60} 分',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _isDurationManual ? Colors.orange.shade700 : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // ===== 離陸場所 =====
            Row(
              children: [
                const Text('離陸場所', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const Spacer(),
                // お気に入り場所ボタン
                OutlinedButton.icon(
                  onPressed: () => _showFavoriteLocations(),
                  icon: const Icon(Icons.star, size: 14),
                  label: const Text('お気に入り'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showLocationPicker = !_showLocationPicker);
                  },
                  icon: const Icon(Icons.location_on, size: 16),
                  label: const Text('位置情報'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5A80),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _takeoffLocationController,
              decoration: InputDecoration(
                hintText: '住所を入力',
                border: const OutlineInputBorder(),
                // 現在の住所をお気に入りに追加するボタン
                suffixIcon: _takeoffLocationController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.star_border, size: 20),
                        tooltip: 'お気に入りに追加',
                        onPressed: () => _addCurrentLocationToFavorites(),
                      )
                    : null,
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),

            // 位置情報ピッカー（展開式）
            if (_showLocationPicker)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: LocationPickerTab(
                  addressController: _takeoffLocationController,
                  onLocationPicked: (result) {
                    if (result.address != null) {
                      setState(() {
                        _takeoffLocationController.text = result.address!;
                        _takeoffLatitude = result.latitude;
                        _takeoffLongitude = result.longitude;
                      });
                    }
                  },
                ),
              ),

            // 座標DMS表示
            if (_takeoffLatitude != null && _takeoffLongitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatDms(_takeoffLatitude!, _takeoffLongitude!),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // 着陸場所
            Row(
              children: [
                const Text('着陸場所', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const Spacer(),
                Checkbox(
                  value: _landingSameAsTakeoff,
                  onChanged: (v) => setState(() => _landingSameAsTakeoff = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const Text('離陸場所と同じ', style: TextStyle(fontSize: 13)),
              ],
            ),
            if (!_landingSameAsTakeoff) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _landingLocationController,
                decoration: const InputDecoration(
                  hintText: '着陸場所を入力',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // ===== 日の出・日の入り =====
            _SunriseSunsetCard(
              data: _sunData,
              isLoading: _isLoadingSun,
              error: _sunError,
              onRetry: _fetchSunriseSunset,
            ),

            // 飛行時間サマリー
            if (duration != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    '飛行時間: ${duration ~/ 60} 時間 ${duration % 60} 分',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // ===== 目的・操縦者・機体 =====
            Card(
              elevation: 0,
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // 目的
                    _buildFormRow(
                      label: '目的',
                      child: DropdownButtonFormField<String>(
                        initialValue: _flightPurposeController.text.isNotEmpty
                            ? _flightPurposeController.text
                            : null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        items: ['空撮', '測量', '点検', '農薬散布', '物流', '練習', 'その他']
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _flightPurposeController.text = v;
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    // 操縦者（必須）
                    pilotsAsync.when(
                      data: (pilots) => _buildFormRow(
                        label: '操縦者 *',
                        hasError: _showValidationErrors && _selectedPilotId == null,
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedPilotId,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: '選択してください',
                            hintStyle: TextStyle(
                              color: _showValidationErrors && _selectedPilotId == null
                                  ? Colors.red[300]
                                  : Colors.grey,
                            ),
                          ),
                          items: pilots
                              .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selectedPilotId = v);
                            if (v != null) _checkPilotStatus(v);
                          },
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('操縦者読み込みエラー'),
                    ),

                    // 操縦者ステータス表示
                    if (_isLoadingPilotStatus)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: LinearProgressIndicator(),
                      ),
                    if (_pilotStatus != null && !_isLoadingPilotStatus && _pilotStatus!.warnings.isNotEmpty)
                      _PilotStatusBanner(status: _pilotStatus!),

                    const Divider(height: 1),
                    // 無人航空機（必須）
                    aircraftsAsync.when(
                      data: (aircrafts) => _buildFormRow(
                        label: '無人航空機 *',
                        hasError: _showValidationErrors && _selectedAircraftId == null,
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedAircraftId,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: '選択してください',
                            hintStyle: TextStyle(
                              color: _showValidationErrors && _selectedAircraftId == null
                                  ? Colors.red[300]
                                  : Colors.grey,
                            ),
                          ),
                          isExpanded: true,
                          items: aircrafts
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(
                                      '${a.registrationNumber} ${a.modelName ?? ""}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selectedAircraftId = v);
                            if (v != null) _checkAircraftSafety(v);
                          },
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('機体読み込みエラー'),
                    ),

                    // 機体安全ステータス表示
                    if (_isLoadingSafety)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                    if (_safetyStatus != null && !_isLoadingSafety)
                      _AircraftSafetyBanner(status: _safetyStatus!),

                    const Divider(height: 1),
                    // 空域・方法
                    _buildFormRow(
                      label: '空域・方法',
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFlightArea,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        items: _flightAreas
                            .map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedFlightArea = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 経路・経由地等
            Card(
              elevation: 0,
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('経路・経由地等', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _routeController,
                      decoration: const InputDecoration(
                        hintText: '直接入力',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ===== 監督者 =====
            SupervisorChips(
              supervisorNames: _supervisorNames,
              onEdit: _openSupervisorSelector,
            ),
            const SizedBox(height: 12),

            // ===== 安全影響・不具合 =====
            InkWell(
              onTap: () async {
                final result = await _showTextInputDialog(
                  title: '飛行の安全に影響のあった事項',
                  initialValue: _safetyIncident,
                );
                if (result != null && mounted) {
                  setState(() => _safetyIncident = result.isEmpty ? null : result);
                }
              },
              child: Card(
                elevation: 0,
                color: _safetyIncident != null ? Colors.orange[50] : Colors.teal[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '飛行の安全に影響のあった事項',
                              style: TextStyle(fontSize: 13),
                            ),
                            if (_safetyIncident != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _safetyIncident!,
                                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _safetyIncident != null ? Colors.orange : Colors.teal,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _safetyIncident != null ? 'あり' : 'なし',
                          style: TextStyle(
                            fontSize: 13,
                            color: _safetyIncident != null ? Colors.orange : Colors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final result = await _showTextInputDialog(
                  title: '不具合事項',
                  initialValue: _defectDetail,
                );
                if (result != null && mounted) {
                  setState(() => _defectDetail = result.isEmpty ? null : result);
                }
              },
              child: Card(
                elevation: 0,
                color: _defectDetail != null ? Colors.orange[50] : Colors.teal[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('不具合事項', style: TextStyle(fontSize: 13)),
                            if (_defectDetail != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _defectDetail!,
                                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _defectDetail != null ? Colors.orange : Colors.teal,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _defectDetail != null ? 'あり' : 'なし',
                          style: TextStyle(
                            fontSize: 13,
                            color: _defectDetail != null ? Colors.orange : Colors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ===== 保存ボタン =====
            ElevatedButton.icon(
              onPressed: formState.isLoading ? null : _submit,
              icon: formState.isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('保存'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// フォーム行: ラベル + 入力ウィジェット
  Widget _buildFormRow({required String label, required Widget child, bool hasError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: hasError ? Colors.red : Colors.grey,
                fontWeight: hasError ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 遵守事項の進捗バッジ
class _ComplianceBadge extends StatelessWidget {
  final Map<String, bool> checks;
  const _ComplianceBadge({required this.checks});

  @override
  Widget build(BuildContext context) {
    final total = checks.length;
    final done = checks.values.where((v) => v).length;
    final allDone = done == total && total > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: allDone ? Colors.green[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$done/$total',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: allDone ? Colors.green[700] : Colors.orange[700],
        ),
      ),
    );
  }
}

/// フライト前チェックの進捗バッジ
class _PreflightBadge extends StatelessWidget {
  final Map<String, bool> checks;
  const _PreflightBadge({required this.checks});

  @override
  Widget build(BuildContext context) {
    final total = checks.length;
    final done = checks.values.where((v) => v).length;
    final allDone = done == total && total > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: allDone ? Colors.green[100] : Colors.blue[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$done/$total',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: allDone ? Colors.green[700] : Colors.blue[700],
        ),
      ),
    );
  }
}

/// 日の出・日の入り情報カード（簡易版）
class _SunriseSunsetCard extends StatelessWidget {
  final SunriseSunsetData? data;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  const _SunriseSunsetCard({
    required this.data,
    required this.isLoading,
    this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wb_sunny, size: 14, color: Colors.orange[700]),
            const SizedBox(width: 4),
            Text(
              '日の出 ${isLoading ? "--:--" : (data?.sunrise ?? "--:--")}',
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
            ),
            const SizedBox(width: 16),
            Icon(Icons.wb_twilight, size: 14, color: Colors.deepOrange[700]),
            const SizedBox(width: 4),
            Text(
              '日の入 ${isLoading ? "--:--" : (data?.sunset ?? "--:--")}',
              style: TextStyle(fontSize: 12, color: Colors.deepOrange[800]),
            ),
            if (error != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRetry,
                child: Icon(Icons.lock_outline, size: 14, color: Colors.grey[400]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 機体安全ステータスバナー
/// 機体選択後に点検・整備状況を色分けして表示
class _AircraftSafetyBanner extends StatelessWidget {
  final AircraftSafetyStatus status;
  const _AircraftSafetyBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final IconData icon;

    switch (status.safetyLevel) {
      case 'danger':
        bgColor = Colors.red[50]!;
        textColor = Colors.red[900]!;
        icon = Icons.warning_amber_rounded;
        break;
      case 'warning':
        bgColor = Colors.orange[50]!;
        textColor = Colors.orange[900]!;
        icon = Icons.info_outline;
        break;
      default:
        bgColor = Colors.green[50]!;
        textColor = Colors.green[900]!;
        icon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー行
          Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 6),
              Text(
                status.safetyLevel == 'ok'
                    ? '機体状態: 良好'
                    : status.safetyLevel == 'warning'
                        ? '機体状態: 注意'
                        : '機体状態: 要確認',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                '飛行${status.totalFlights}回 / ${status.totalFlightMinutes}分',
                style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7)),
              ),
            ],
          ),
          // 詳細情報
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              if (status.lastInspectionDate != null)
                Text(
                  '最終点検: ${status.lastInspectionDate} (${status.lastInspectionResult})',
                  style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8)),
                ),
              if (status.lastMaintenanceDate != null)
                Text(
                  '最終整備: ${status.lastMaintenanceDate} (${status.lastMaintenanceResult})',
                  style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8)),
                ),
              if (status.nextMaintenanceDate != null)
                Text(
                  '次回整備: ${status.nextMaintenanceDate}',
                  style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8)),
                ),
            ],
          ),
          // 警告メッセージ
          if (status.warnings.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...status.warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(
                        status.safetyLevel == 'danger'
                            ? Icons.error_outline
                            : Icons.warning_amber,
                        size: 12,
                        color: textColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          w,
                          style: TextStyle(fontSize: 11, color: textColor),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

/// 操縦者ステータスバナー
class _PilotStatusBanner extends StatelessWidget {
  final PilotStatusInfo status;
  const _PilotStatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final IconData icon;

    switch (status.statusLevel) {
      case 'danger':
        bgColor = Colors.red[50]!;
        textColor = Colors.red[900]!;
        icon = Icons.warning_amber_rounded;
        break;
      case 'warning':
        bgColor = Colors.orange[50]!;
        textColor = Colors.orange[900]!;
        icon = Icons.info_outline;
        break;
      default:
        bgColor = Colors.green[50]!;
        textColor = Colors.green[900]!;
        icon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 4),
              Text(
                '飛行${status.totalFlights}回 / ${status.totalFlightMinutes}分',
                style: TextStyle(fontSize: 11, color: textColor),
              ),
              if (status.lastFlightDate != null) ...[
                const SizedBox(width: 8),
                Text(
                  '最終: ${status.lastFlightDate}',
                  style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7)),
                ),
              ],
            ],
          ),
          ...status.warnings.map((w) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $w',
                  style: TextStyle(fontSize: 10, color: textColor),
                ),
              )),
        ],
      ),
    );
  }
}
