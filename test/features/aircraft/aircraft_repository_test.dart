import 'package:flutter_test/flutter_test.dart';
import 'package:drone_flight_log/core/database/local_storage.dart';
import 'package:drone_flight_log/features/aircraft/data/repositories/aircraft_repository.dart';

/// LocalStorageのモック実装
/// テスト用にメモリ上でデータを管理する
class MockLocalStorage extends LocalStorage {
  final List<AircraftData> _mockAircrafts = [];
  int _nextId = 1;

  /// 初期化をオーバーライド（ファイルI/Oを無効化）
  @override
  Future<void> init() async {
    // テスト用: ファイルI/Oをスキップ
  }

  @override
  Future<List<AircraftData>> getAllAircrafts() async {
    return _mockAircrafts;
  }

  @override
  Future<AircraftData?> getAircraftById(int id) async {
    try {
      return _mockAircrafts.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int> createAircraft({
    required String registrationNumber,
    required String aircraftType,
    String? manufacturer,
    String? modelName,
    String? serialNumber,
    double? maxTakeoffWeight,
    String? imageUrl,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _nextId;
    _nextId++;

    final aircraft = AircraftData(
      id: id,
      registrationNumber: registrationNumber,
      aircraftType: aircraftType,
      manufacturer: manufacturer,
      modelName: modelName,
      serialNumber: serialNumber,
      maxTakeoffWeight: maxTakeoffWeight,
      totalFlightTime: 0,
      imageUrl: imageUrl,
      createdAt: now,
      updatedAt: now,
    );

    _mockAircrafts.add(aircraft);
    return id;
  }

  @override
  Future<bool> deleteAircraft(int id) async {
    final index = _mockAircrafts.indexWhere((a) => a.id == id);
    if (index == -1) return false;
    _mockAircrafts.removeAt(index);
    return true;
  }

  @override
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
    final index = _mockAircrafts.indexWhere((a) => a.id == id);
    if (index == -1) return false;

    final now = DateTime.now().toIso8601String();
    final existing = _mockAircrafts[index];

    _mockAircrafts[index] = AircraftData(
      id: id,
      registrationNumber: registrationNumber,
      aircraftType: aircraftType,
      manufacturer: manufacturer,
      modelName: modelName,
      serialNumber: serialNumber,
      maxTakeoffWeight: maxTakeoffWeight,
      totalFlightTime: existing.totalFlightTime,
      imageUrl: imageUrl,
      createdAt: existing.createdAt,
      updatedAt: now,
    );

    return true;
  }
}

void main() {
  group('AircraftRepository', () {
    late AircraftRepository aircraftRepository;
    late MockLocalStorage mockStorage;

    setUp(() {
      mockStorage = MockLocalStorage();
      aircraftRepository = AircraftRepository(storage: mockStorage);
    });

    test('初期状態は空のリストを返す', () async {
      // Act: 航空機リストを取得
      final aircrafts = await aircraftRepository.getAllAircrafts();

      // Assert: 空のリストが返されることを確認
      expect(aircrafts, isEmpty);
    });

    test('航空機を作成できる', () async {
      // Act: 航空機を作成
      final aircraftId = await aircraftRepository.createAircraft(
        registrationNumber: 'JU-001',
        aircraftType: 'マルチローター',
        manufacturer: 'DJI',
        modelName: 'Mavic 3',
        serialNumber: 'ABCD1234',
        maxTakeoffWeight: 2000,
      );

      // Assert: IDが1であることを確認
      expect(aircraftId, equals(1));

      // Assert: リストに1件追加されたことを確認
      final aircrafts = await aircraftRepository.getAllAircrafts();
      expect(aircrafts.length, equals(1));
      expect(aircrafts.first.registrationNumber, equals('JU-001'));
    });

    test('航空機を削除できる', () async {
      // Arrange: 航空機を作成
      final id = await aircraftRepository.createAircraft(
        registrationNumber: 'JU-002',
        aircraftType: 'マルチローター',
      );

      // Act: 航空機を削除
      final result = await aircraftRepository.deleteAircraft(id);

      // Assert: 削除が成功したことを確認
      expect(result, isTrue);

      // Assert: リストが空になったことを確認
      final aircrafts = await aircraftRepository.getAllAircrafts();
      expect(aircrafts, isEmpty);
    });

    test('航空機をIDで取得できる', () async {
      // Arrange: 航空機を作成
      await aircraftRepository.createAircraft(
        registrationNumber: 'JU-003',
        aircraftType: '固定翼',
        manufacturer: 'テストメーカー',
      );

      // Act: IDで航空機を取得
      final aircraft = await aircraftRepository.getAircraftById(1);

      // Assert: 正しいデータが返されることを確認
      expect(aircraft, isNotNull);
      expect(aircraft!.registrationNumber, equals('JU-003'));
      expect(aircraft.aircraftType, equals('固定翼'));
    });

    test('存在しないIDではnullが返される', () async {
      // Act: 存在しないIDで航空機を取得
      final aircraft = await aircraftRepository.getAircraftById(999);

      // Assert: nullが返されることを確認
      expect(aircraft, isNull);
    });
  });
}
