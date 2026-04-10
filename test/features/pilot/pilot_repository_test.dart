import 'package:flutter_test/flutter_test.dart';
import 'package:drone_flight_log/core/database/local_storage.dart';
import 'package:drone_flight_log/features/pilot/data/repositories/pilot_repository.dart';

/// LocalStorageのPilot用モック実装
class MockLocalStorage extends LocalStorage {
  final List<PilotData> _mockPilots = [];
  int _nextId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<List<PilotData>> getAllPilots() async {
    return _mockPilots;
  }

  @override
  Future<PilotData?> getPilotById(int id) async {
    try {
      return _mockPilots.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
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
    final now = DateTime.now().toIso8601String();
    final id = _nextId;
    _nextId++;

    _mockPilots.add(PilotData(
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
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  @override
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
    final index = _mockPilots.indexWhere((p) => p.id == id);
    if (index == -1) return false;

    final now = DateTime.now().toIso8601String();
    final existing = _mockPilots[index];

    _mockPilots[index] = PilotData(
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
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    return true;
  }

  @override
  Future<bool> deletePilot(int id) async {
    final index = _mockPilots.indexWhere((p) => p.id == id);
    if (index == -1) return false;
    _mockPilots.removeAt(index);
    return true;
  }
}

void main() {
  group('PilotRepository', () {
    late PilotRepository repository;
    late MockLocalStorage mockStorage;

    setUp(() {
      mockStorage = MockLocalStorage();
      repository = PilotRepository(storage: mockStorage);
    });

    test('初期状態は空のリストを返す', () async {
      final pilots = await repository.getAllPilots();
      expect(pilots, isEmpty);
    });

    test('操縦者を作成できる', () async {
      final id = await repository.createPilot(
        name: '石川 啓',
        licenseType: '一等',
        organization: 'DRONE PEAK',
      );

      expect(id, equals(1));

      final pilots = await repository.getAllPilots();
      expect(pilots.length, equals(1));
      expect(pilots.first.name, equals('石川 啓'));
      expect(pilots.first.licenseType, equals('一等'));
      expect(pilots.first.organization, equals('DRONE PEAK'));
    });

    test('操縦者をIDで取得できる', () async {
      await repository.createPilot(
        name: '田中 太郎',
        licenseNumber: 'LIC-001',
        contact: '090-1234-5678',
      );

      final pilot = await repository.getPilotById(1);
      expect(pilot, isNotNull);
      expect(pilot!.name, equals('田中 太郎'));
      expect(pilot.licenseNumber, equals('LIC-001'));
    });

    test('存在しないIDではnullが返される', () async {
      final pilot = await repository.getPilotById(999);
      expect(pilot, isNull);
    });

    test('操縦者を更新できる', () async {
      await repository.createPilot(name: '元の名前');

      final result = await repository.updatePilot(
        id: 1,
        name: '更新後の名前',
        licenseType: '二等',
      );

      expect(result, isTrue);

      final pilot = await repository.getPilotById(1);
      expect(pilot!.name, equals('更新後の名前'));
      expect(pilot.licenseType, equals('二等'));
    });

    test('存在しないIDの更新はfalseを返す', () async {
      final result = await repository.updatePilot(id: 999, name: 'テスト');
      expect(result, isFalse);
    });

    test('操縦者を削除できる', () async {
      final id = await repository.createPilot(name: '削除対象');

      final result = await repository.deletePilot(id);
      expect(result, isTrue);

      final pilots = await repository.getAllPilots();
      expect(pilots, isEmpty);
    });

    test('存在しないIDの削除はfalseを返す', () async {
      final result = await repository.deletePilot(999);
      expect(result, isFalse);
    });

    test('技能証明書フィールドが正しく保存される', () async {
      await repository.createPilot(
        name: '証明書テスト',
        certificateNumber: 'CERT-001',
        certificateIssueDate: '2025-01-01',
        certificateRegistrationDate: '2025-01-15',
        autoRegister: true,
      );

      final pilot = await repository.getPilotById(1);
      expect(pilot!.certificateNumber, equals('CERT-001'));
      expect(pilot.certificateIssueDate, equals('2025-01-01'));
      expect(pilot.certificateRegistrationDate, equals('2025-01-15'));
      expect(pilot.autoRegister, isTrue);
    });

    test('Pilotエンティティに正しく変換される', () async {
      await repository.createPilot(
        name: '変換テスト',
        licenseType: '一等',
      );

      final pilot = await repository.getPilotById(1);
      // PilotエンティティのcreatedAt/updatedAtはDateTime型
      expect(pilot!.createdAt, isA<DateTime>());
      expect(pilot.updatedAt, isA<DateTime>());
    });
  });
}
