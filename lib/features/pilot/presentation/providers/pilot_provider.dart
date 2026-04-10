import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/local_storage.dart';
import '../../data/repositories/pilot_repository.dart';
import '../../domain/entities/pilot.dart';

/// ローカルストレージプロバイダ（既に定義済み）
// import from local_storage.dart

/// パイロットリポジトリプロバイダ
final pilotRepositoryProvider = FutureProvider<PilotRepository>((ref) async {
  final storage = await ref.watch(localStorageProvider.future);
  return PilotRepository(storage: storage);
});

/// すべてのパイロットのプロバイダ
/// パイロットリストを Future で取得
final pilotListProvider = FutureProvider<List<Pilot>>((ref) async {
  final repository = await ref.watch(pilotRepositoryProvider.future);
  return repository.getAllPilots();
});

/// 現在選択されているパイロットのプロバイダ
final currentPilotProvider = StateProvider<Pilot?>((ref) {
  return null;
});

/// パイロット追加・編集用のStateNotifierプロバイダ
final pilotFormProvider =
    StateNotifierProvider<PilotFormNotifier, PilotFormState>((ref) {
  return PilotFormNotifier(ref: ref);
});

/// パイロットフォームの状態
class PilotFormState {
  final bool isLoading;
  final String? error;
  final Pilot? savedPilot;

  const PilotFormState({
    this.isLoading = false,
    this.error,
    this.savedPilot,
  });

  PilotFormState copyWith({
    bool? isLoading,
    String? error,
    Pilot? savedPilot,
  }) {
    return PilotFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      savedPilot: savedPilot ?? this.savedPilot,
    );
  }
}

/// パイロットフォーム用StateNotifier
class PilotFormNotifier extends StateNotifier<PilotFormState> {
  final Ref _ref;

  /// コンストラクタ
  PilotFormNotifier({required Ref ref})
      : _ref = ref,
        super(const PilotFormState());

  /// パイロットを保存（作成または更新）
  /// パイロットIDがnullの場合は新規作成、それ以外は更新
  Future<void> savePilot({
    int? id,
    required String name,
    String? licenseNumber,
    String? licenseType,
    String? licenseExpiry,
    String? organization,
    String? contact,
    String? certificateNumber,
    String? certificateIssueDate,
    String? certificateRegistrationDate,
    bool autoRegister = false,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = await _ref.read(pilotRepositoryProvider.future);
      if (id == null) {
        // 新規作成
        final pilotId = await repository.createPilot(
          name: name,
          licenseNumber: licenseNumber,
          licenseType: licenseType,
          licenseExpiry: licenseExpiry,
          organization: organization,
          contact: contact,
          certificateNumber: certificateNumber,
          certificateIssueDate: certificateIssueDate,
          certificateRegistrationDate: certificateRegistrationDate,
          autoRegister: autoRegister,
        );
        final savedPilot = await repository.getPilotById(pilotId);
        state = state.copyWith(
          isLoading: false,
          savedPilot: savedPilot,
        );
      } else {
        // 更新
        await repository.updatePilot(
          id: id,
          name: name,
          licenseNumber: licenseNumber,
          licenseType: licenseType,
          licenseExpiry: licenseExpiry,
          organization: organization,
          contact: contact,
          certificateNumber: certificateNumber,
          certificateIssueDate: certificateIssueDate,
          certificateRegistrationDate: certificateRegistrationDate,
          autoRegister: autoRegister,
        );
        final savedPilot = await repository.getPilotById(id);
        state = state.copyWith(
          isLoading: false,
          savedPilot: savedPilot,
        );
      }
      // リスト更新をトリガー
      _ref.invalidate(pilotListProvider);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  /// パイロットを削除
  Future<void> deletePilot(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = await _ref.read(pilotRepositoryProvider.future);
      await repository.deletePilot(id);
      state = state.copyWith(isLoading: false);
      // リスト更新をトリガー
      _ref.invalidate(pilotListProvider);
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

  /// 保存済みパイロットをクリア
  void clearSavedPilot() {
    state = state.copyWith(savedPilot: null);
  }
}
