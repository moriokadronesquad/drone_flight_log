import '../../../../core/database/local_storage.dart';
import '../../domain/entities/aircraft.dart';

/// 航空機リポジトリ
/// ローカルストレージを使用してCRUD操作を実行
class AircraftRepository {
  final LocalStorage _storage;

  /// コンストラクタ
  AircraftRepository({required LocalStorage storage}) : _storage = storage;

  /// すべての航空機を取得
  /// 返り値: 航空機リストの Future
  Future<List<Aircraft>> getAllAircrafts() async {
    final aircraftDataList = await _storage.getAllAircrafts();
    return aircraftDataList
        .map((data) => _convertToEntity(data))
        .toList();
  }

  /// IDで航空機を取得
  Future<Aircraft?> getAircraftById(int id) async {
    final aircraftData = await _storage.getAircraftById(id);
    return aircraftData != null ? _convertToEntity(aircraftData) : null;
  }

  /// 航空機を作成
  /// 登録番号は重複しないようにチェック
  /// 返り値: 作成された航空機のID
  Future<int> createAircraft({
    required String registrationNumber,
    required String aircraftType,
    String? manufacturer,
    String? modelName,
    String? serialNumber,
    double? maxTakeoffWeight,
    String? imageUrl,
  }) async {
    return _storage.createAircraft(
      registrationNumber: registrationNumber,
      aircraftType: aircraftType,
      manufacturer: manufacturer,
      modelName: modelName,
      serialNumber: serialNumber,
      maxTakeoffWeight: maxTakeoffWeight,
      imageUrl: imageUrl,
    );
  }

  /// 航空機を更新
  /// 返り値: 更新成功時true
  Future<bool> updateAircraft({
    required int id,
    required String registrationNumber,
    required String aircraftType,
    String? manufacturer,
    String? modelName,
    String? serialNumber,
    double? maxTakeoffWeight,
    String? imageUrl,
  }) async {
    return _storage.updateAircraft(
      id: id,
      registrationNumber: registrationNumber,
      aircraftType: aircraftType,
      manufacturer: manufacturer,
      modelName: modelName,
      serialNumber: serialNumber,
      maxTakeoffWeight: maxTakeoffWeight,
      imageUrl: imageUrl,
    );
  }

  /// 航空機を削除
  /// 返り値: 削除成功時true
  Future<bool> deleteAircraft(int id) async {
    return _storage.deleteAircraft(id);
  }

  /// データベースエンティティをドメインエンティティに変換
  Aircraft _convertToEntity(AircraftData data) {
    return Aircraft(
      id: data.id,
      registrationNumber: data.registrationNumber,
      aircraftType: data.aircraftType,
      manufacturer: data.manufacturer,
      modelName: data.modelName,
      serialNumber: data.serialNumber,
      maxTakeoffWeight: data.maxTakeoffWeight,
      totalFlightTime: data.totalFlightTime,
      imageUrl: data.imageUrl,
      createdAt: DateTime.parse(data.createdAt),
      updatedAt: DateTime.parse(data.updatedAt),
    );
  }
}
