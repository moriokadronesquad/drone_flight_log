import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/flight_log_storage.dart';

/// FlightLogStorageプロバイダ
final flightLogStorageProvider = FutureProvider<FlightLogStorage>((ref) async {
  final storage = FlightLogStorage();
  await storage.init();
  return storage;
});

/// 飛行実績一覧プロバイダ
final flightListProvider =
    FutureProvider<List<FlightRecordData>>((ref) async {
  final storage = await ref.watch(flightLogStorageProvider.future);
  return storage.getAllFlights();
});

/// 日常点検一覧プロバイダ
final inspectionListProvider =
    FutureProvider<List<DailyInspectionData>>((ref) async {
  final storage = await ref.watch(flightLogStorageProvider.future);
  return storage.getAllInspections();
});

/// 整備記録一覧プロバイダ
final maintenanceListProvider =
    FutureProvider<List<MaintenanceRecordData>>((ref) async {
  final storage = await ref.watch(flightLogStorageProvider.future);
  return storage.getAllMaintenances();
});

/// 飛行実績フォーム用StateNotifier
final flightFormProvider =
    StateNotifierProvider<FlightFormNotifier, FlightFormState>((ref) {
  return FlightFormNotifier(ref: ref);
});

class FlightFormState {
  final bool isLoading;
  final String? error;

  const FlightFormState({this.isLoading = false, this.error});

  FlightFormState copyWith({bool? isLoading, String? error}) {
    return FlightFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class FlightFormNotifier extends StateNotifier<FlightFormState> {
  final Ref _ref;

  FlightFormNotifier({required Ref ref})
      : _ref = ref,
        super(const FlightFormState());

  /// 飛行実績を保存
  Future<void> saveFlight({
    required int aircraftId,
    required int pilotId,
    required String flightDate,
    String? takeoffTime,
    String? landingTime,
    int? flightDuration,
    String? takeoffLocation,
    String? landingLocation,
    String? flightPurpose,
    String? flightArea,
    String? maxAltitude,
    String? weather,
    String? windSpeed,
    String? temperature,
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
    // Phase 4.5: 拡張フィールド
    int? batteryBefore,
    int? batteryAfter,
    String? batteryNumber,
    String? flightDistance,
    String? ownerConsent,
    double? takeoffLatitude,
    double? takeoffLongitude,
    double? landingLatitude,
    double? landingLongitude,
    Map<String, bool> complianceChecks = const {},
    String? permitName,
    String? permitNumber,
    String? permitStartDate,
    String? permitEndDate,
    String? permitItems,
    String? permitNotes,
    String? safetyIncident,
    String? defectDetail,
    List<Map<String, String>> photoAttachments = const [],
    List<Map<String, String>> pdfAttachments = const [],
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final storage = await _ref.read(flightLogStorageProvider.future);
      await storage.createFlight(
        aircraftId: aircraftId,
        pilotId: pilotId,
        flightDate: flightDate,
        takeoffTime: takeoffTime,
        landingTime: landingTime,
        flightDuration: flightDuration,
        takeoffLocation: takeoffLocation,
        landingLocation: landingLocation,
        flightPurpose: flightPurpose,
        flightArea: flightArea,
        maxAltitude: maxAltitude,
        weather: weather,
        windSpeed: windSpeed,
        temperature: temperature,
        notes: notes,
        supervisorIds: supervisorIds,
        supervisorNames: supervisorNames,
        batteryBefore: batteryBefore,
        batteryAfter: batteryAfter,
        batteryNumber: batteryNumber,
        flightDistance: flightDistance,
        ownerConsent: ownerConsent,
        takeoffLatitude: takeoffLatitude,
        takeoffLongitude: takeoffLongitude,
        landingLatitude: landingLatitude,
        landingLongitude: landingLongitude,
        complianceChecks: complianceChecks,
        permitName: permitName,
        permitNumber: permitNumber,
        permitStartDate: permitStartDate,
        permitEndDate: permitEndDate,
        permitItems: permitItems,
        permitNotes: permitNotes,
        safetyIncident: safetyIncident,
        defectDetail: defectDetail,
        photoAttachments: photoAttachments,
        pdfAttachments: pdfAttachments,
      );
      state = state.copyWith(isLoading: false);
      _ref.invalidate(flightListProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// 飛行実績を更新
  Future<void> updateFlight({
    required int id,
    required int aircraftId,
    required int pilotId,
    required String flightDate,
    String? takeoffTime,
    String? landingTime,
    int? flightDuration,
    String? takeoffLocation,
    String? landingLocation,
    String? flightPurpose,
    String? flightArea,
    String? maxAltitude,
    String? weather,
    String? windSpeed,
    String? temperature,
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
    int? batteryBefore,
    int? batteryAfter,
    String? batteryNumber,
    String? flightDistance,
    String? ownerConsent,
    double? takeoffLatitude,
    double? takeoffLongitude,
    Map<String, bool> complianceChecks = const {},
    String? permitName,
    String? permitNumber,
    String? permitStartDate,
    String? permitEndDate,
    String? permitItems,
    String? permitNotes,
    String? safetyIncident,
    String? defectDetail,
    List<Map<String, String>> photoAttachments = const [],
    List<Map<String, String>> pdfAttachments = const [],
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final storage = await _ref.read(flightLogStorageProvider.future);
      await storage.updateFlight(
        id: id,
        aircraftId: aircraftId,
        pilotId: pilotId,
        flightDate: flightDate,
        takeoffTime: takeoffTime,
        landingTime: landingTime,
        flightDuration: flightDuration,
        takeoffLocation: takeoffLocation,
        landingLocation: landingLocation,
        flightPurpose: flightPurpose,
        flightArea: flightArea,
        maxAltitude: maxAltitude,
        weather: weather,
        windSpeed: windSpeed,
        temperature: temperature,
        notes: notes,
        supervisorIds: supervisorIds,
        supervisorNames: supervisorNames,
        batteryBefore: batteryBefore,
        batteryAfter: batteryAfter,
        batteryNumber: batteryNumber,
        flightDistance: flightDistance,
        ownerConsent: ownerConsent,
        takeoffLatitude: takeoffLatitude,
        takeoffLongitude: takeoffLongitude,
        complianceChecks: complianceChecks,
        permitName: permitName,
        permitNumber: permitNumber,
        permitStartDate: permitStartDate,
        permitEndDate: permitEndDate,
        permitItems: permitItems,
        permitNotes: permitNotes,
        safetyIncident: safetyIncident,
        defectDetail: defectDetail,
        photoAttachments: photoAttachments,
        pdfAttachments: pdfAttachments,
      );
      state = state.copyWith(isLoading: false);
      _ref.invalidate(flightListProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// 飛行実績を削除
  Future<void> deleteFlight(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      final storage = await _ref.read(flightLogStorageProvider.future);
      await storage.deleteFlight(id);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(flightListProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// CSVから飛行記録を一括インポート
  Future<int> importFlights(List<Map<String, String>> records) async {
    state = state.copyWith(isLoading: true);
    try {
      final storage = await _ref.read(flightLogStorageProvider.future);
      final count = await storage.importFlights(records);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(flightListProvider);
      return count;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return 0;
    }
  }
}

/// 日常点検フォーム用StateNotifier
final inspectionFormProvider =
    StateNotifierProvider<InspectionFormNotifier, InspectionFormState>((ref) {
  return InspectionFormNotifier(ref: ref);
});

class InspectionFormState {
  final bool isLoading;
  final String? error;

  const InspectionFormState({this.isLoading = false, this.error});

  InspectionFormState copyWith({bool? isLoading, String? error}) {
    return InspectionFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InspectionFormNotifier extends StateNotifier<InspectionFormState> {
  final Ref _ref;

  InspectionFormNotifier({required Ref ref})
      : _ref = ref,
        super(const InspectionFormState());

  /// 日常点検を保存
  Future<void> saveInspection({
    required int aircraftId,
    required int inspectorId,
    required String inspectionDate,
    bool frameCheck = false,
    bool propellerCheck = false,
    bool motorCheck = false,
    bool batteryCheck = false,
    bool controllerCheck = false,
    bool gpsCheck = false,
    bool cameraCheck = false,
    bool communicationCheck = false,
    String overallResult = '合格',
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final storage = await _ref.read(flightLogStorageProvider.future);
      await storage.createInspection(
        aircraftId: aircraftId,
        inspectorId: inspectorId,
        inspectionDate: inspectionDate,
        frameCheck: frameCheck,
        propellerCheck: propellerCheck,
        motorCheck: motorCheck,
        batteryCheck: batteryCheck,
        controllerCheck: controllerCheck,
        gpsCheck: gpsCheck,
        cameraCheck: cameraCheck,
        communicationCheck: communicationCheck,
        overallResult: overallResult,
        notes: notes,
        supervisorIds: supervisorIds,
        supervisorNames: supervisorNames,
      );
      state = state.copyWith(isLoading: false);
      _ref.invalidate(inspectionListProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// 日常点検を更新
  Future<void> updateInspection({
    required int id,
    required int aircraftId,
    required int inspectorId,
    required String inspectionDate,
    bool frameCheck = false,
    bool propellerCheck = false,
    bool motorCheck = false,
    bool batteryCheck = false,
    bool controllerCheck = false,
    bool gpsCheck = false,
    bool cameraCheck = false,
    bool communicationCheck = false,
    String overallResult = '合格',
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final storage = await _ref.read(flightLogStorageProvider.future);
      await storage.updateInspection(
        id: id,
        aircraftId: aircraftId,
        inspectorId: inspectorId,
        inspectionDate: inspectionDate,
        frameCheck: frameCheck,
        propellerCheck: propellerCheck,
        motorCheck: motorCheck,
        batteryCheck: batteryCheck,
        controllerCheck: controllerCheck,
        gpsCheck: gpsCheck,
        cameraCheck: cameraCheck,
        communicationCheck: communicationCheck,
        overallResult: overallResult,
        notes: notes,
        supervisorIds: supervisorIds,
        supervisorNames: supervisorNames,
      );
      state = state.copyWith(isLoading: false);
      _ref.invalidate(inspectionListProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// 日常点検を削除
  Future<void> deleteInspection(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      final storage = await _ref.read(flightLogStorageProvider.future);
      await storage.deleteInspection(id);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(inspectionListProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}

/// 整備記録フォーム用StateNotifier
final maintenanceFormProvider =
    StateNotifierProvider<MaintenanceFormNotifier, MaintenanceFormState>((ref) {
  return MaintenanceFormNotifier(ref: ref);
});

class MaintenanceFormState {
  final bool isLoading;
  final String? error;

  const MaintenanceFormState({this.isLoading = false, this.error});

  MaintenanceFormState copyWith({bool? isLoading, String? error}) {
    return MaintenanceFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MaintenanceFormNotifier extends StateNotifier<MaintenanceFormState> {
  final Ref _ref;

  MaintenanceFormNotifier({required Ref ref})
      : _ref = ref,
        super(const MaintenanceFormState());

  /// 整備記録を保存
  Future<void> saveMaintenance({
    required int aircraftId,
    required int maintainerId,
    required String maintenanceDate,
    required String maintenanceType,
    String? description,
    String? partsReplaced,
    String? result,
    String? nextMaintenanceDate,
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final storage = await _ref.read(flightLogStorageProvider.future);
      await storage.createMaintenance(
        aircraftId: aircraftId,
        maintainerId: maintainerId,
        maintenanceDate: maintenanceDate,
        maintenanceType: maintenanceType,
        description: description,
        partsReplaced: partsReplaced,
        result: result,
        nextMaintenanceDate: nextMaintenanceDate,
        notes: notes,
        supervisorIds: supervisorIds,
        supervisorNames: supervisorNames,
      );
      state = state.copyWith(isLoading: false);
      _ref.invalidate(maintenanceListProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// 整備記録を削除
  /// 整備記録を更新
  Future<void> updateMaintenance({
    required int id,
    required int aircraftId,
    required int maintainerId,
    required String maintenanceDate,
    required String maintenanceType,
    String? description,
    String? partsReplaced,
    String? result,
    String? nextMaintenanceDate,
    String? notes,
    List<int> supervisorIds = const [],
    List<String> supervisorNames = const [],
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final storage = await _ref.read(flightLogStorageProvider.future);
      await storage.updateMaintenance(
        id: id,
        aircraftId: aircraftId,
        maintainerId: maintainerId,
        maintenanceDate: maintenanceDate,
        maintenanceType: maintenanceType,
        description: description,
        partsReplaced: partsReplaced,
        result: result,
        nextMaintenanceDate: nextMaintenanceDate,
        notes: notes,
        supervisorIds: supervisorIds,
        supervisorNames: supervisorNames,
      );
      state = state.copyWith(isLoading: false);
      _ref.invalidate(maintenanceListProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> deleteMaintenance(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      final storage = await _ref.read(flightLogStorageProvider.future);
      await storage.deleteMaintenance(id);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(maintenanceListProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}
