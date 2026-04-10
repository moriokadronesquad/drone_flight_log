import '../../../../core/database/local_storage.dart';
import '../../domain/entities/pilot.dart';

/// パイロットリポジトリ
/// ローカルストレージを使用してCRUD操作を実行
class PilotRepository {
  final LocalStorage _storage;

  /// コンストラクタ
  PilotRepository({required LocalStorage storage}) : _storage = storage;

  /// すべてのパイロットを取得
  /// 返り値: パイロットリストの Future
  Future<List<Pilot>> getAllPilots() async {
    final pilotDataList = await _storage.getAllPilots();
    return pilotDataList
        .map((data) => _convertToEntity(data))
        .toList();
  }

  /// IDでパイロットを取得
  Future<Pilot?> getPilotById(int id) async {
    final pilotData = await _storage.getPilotById(id);
    return pilotData != null ? _convertToEntity(pilotData) : null;
  }

  /// パイロットを作成
  /// 返り値: 作成されたパイロットのID
  Future<int> createPilot({
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
    return _storage.createPilot(
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
  }

  /// パイロットを更新
  /// 返り値: 更新成功時true
  Future<bool> updatePilot({
    required int id,
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
    return _storage.updatePilot(
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
  }

  /// パイロットを削除
  /// 返り値: 削除成功時true
  Future<bool> deletePilot(int id) async {
    return _storage.deletePilot(id);
  }

  /// データベースエンティティをドメインエンティティに変換
  Pilot _convertToEntity(PilotData data) {
    return Pilot(
      id: data.id,
      name: data.name,
      licenseNumber: data.licenseNumber,
      licenseType: data.licenseType,
      licenseExpiry: data.licenseExpiry,
      organization: data.organization,
      contact: data.contact,
      certificateNumber: data.certificateNumber,
      certificateIssueDate: data.certificateIssueDate,
      certificateRegistrationDate: data.certificateRegistrationDate,
      autoRegister: data.autoRegister,
      createdAt: DateTime.parse(data.createdAt),
      updatedAt: DateTime.parse(data.updatedAt),
    );
  }
}
