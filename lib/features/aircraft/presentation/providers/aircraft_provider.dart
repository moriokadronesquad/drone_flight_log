import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/local_storage.dart';
import '../../data/repositories/aircraft_repository.dart';
import '../../domain/entities/aircraft.dart';

/// ローカルストレージプロバイダ（既に定義済み）
// import from local_storage.dart

/// 航空機リポジトリプロバイダ
final aircraftRepositoryProvider = FutureProvider<AircraftRepository>((ref) async {
  final storage = await ref.watch(localStorageProvider.future);
  return AircraftRepository(storage: storage);
});

/// すべての航空機のプロバイダ
/// 航空機リストを Future で取得
final aircraftListProvider =
    FutureProvider<List<Aircraft>>((ref) async {
  final repository = await ref.watch(aircraftRepositoryProvider.future);
  return repository.getAllAircrafts();
});

/// 現在選択されている航空機のプロバイダ
final currentAircraftProvider = StateProvider<Aircraft?>((ref) {
  return null;
});

/// 航空機追加・編集用のStateNotifierプロバイダ
final aircraftFormProvider =
    StateNotifierProvider<AircraftFormNotifier, AircraftFormState>((ref) {
  return AircraftFormNotifier(ref: ref);
});

/// 航空機フォームの状態
class AircraftFormState {
  final bool isLoading;
  final String? error;
  final Aircraft? savedAircraft;

  const AircraftFormState({
    this.isLoading = false,
    this.error,
    this.savedAircraft,
  });

  AircraftFormState copyWith({
    bool? isLoading,
    String? error,
    Aircraft? savedAircraft,
  }) {
    return AircraftFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      savedAircraft: savedAircraft ?? this.savedAircraft,
    );
  }
}

/// 航空機フォーム用StateNotifier
class AircraftFormNotifier extends StateNotifier<AircraftFormState> {
  final Ref _ref;

  /// コンストラクタ
  AircraftFormNotifier({required Ref ref})
      : _ref = ref,
        super(const AircraftFormState());

  /// 航空機を保存（作成または更新）
  /// 航空機IDがnullの場合は新規作成、それ以外は更新
  Future<void> saveAircraft({
    int? id,
    required String registrationNumber,
    required String aircraftType,
    String? manufacturer,
    String? modelName,
    String? serialNumber,
    double? maxTakeoffWeight,
    String? imageUrl,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = await _ref.read(aircraftRepositoryProvider.future);
      if (id == null) {
        // 新規作成
        final aircraftId = await repository.createAircraft(
          registrationNumber: registrationNumber,
          aircraftType: aircraftType,
          manufacturer: manufacturer,
          modelName: modelName,
          serialNumber: serialNumber,
          maxTakeoffWeight: maxTakeoffWeight,
          imageUrl: imageUrl,
        );
        final savedAircraft = await repository.getAircraftById(aircraftId);
        state = state.copyWith(
          isLoading: false,
          savedAircraft: savedAircraft,
        );
      } else {
        // 更新
        await repository.updateAircraft(
          id: id,
          registrationNumber: registrationNumber,
          aircraftType: aircraftType,
          manufacturer: manufacturer,
          modelName: modelName,
          serialNumber: serialNumber,
          maxTakeoffWeight: maxTakeoffWeight,
          imageUrl: imageUrl,
        );
        final savedAircraft = await repository.getAircraftById(id);
        state = state.copyWith(
          isLoading: false,
          savedAircraft: savedAircraft,
        );
      }
      // リスト更新をトリガー
      _ref.invalidate(aircraftListProvider);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  /// 航空機を削除
  Future<void> deleteAircraft(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = await _ref.read(aircraftRepositoryProvider.future);
      await repository.deleteAircraft(id);
      state = state.copyWith(isLoading: false);
      // リスト更新をトリガー
      _ref.invalidate(aircraftListProvider);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  /// エラーをクリア
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 保存済み航空機をクリア
  void clearSavedAircraft() {
    state = state.copyWith(savedAircraft: null);
  }
}
