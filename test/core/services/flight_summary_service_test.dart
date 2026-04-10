import 'package:flutter_test/flutter_test.dart';
import 'package:drone_flight_log/core/services/flight_summary_service.dart';
import 'package:drone_flight_log/core/database/flight_log_storage.dart';

/// テスト用FlightRecordDataヘルパー
FlightRecordData _makeFlightRecord({
  int id = 1,
  int aircraftId = 1,
  int pilotId = 1,
  String flightDate = '2026-04-10',
  String? takeoffTime = '10:00',
  String? landingTime = '10:30',
  int? flightDuration = 30,
  String? takeoffLocation = '盛岡市内',
  String? flightPurpose = '点検業務',
  String? notes,
}) {
  return FlightRecordData(
    id: id,
    aircraftId: aircraftId,
    pilotId: pilotId,
    flightDate: flightDate,
    takeoffTime: takeoffTime,
    landingTime: landingTime,
    flightDuration: flightDuration,
    takeoffLocation: takeoffLocation,
    flightPurpose: flightPurpose,
    notes: notes,
    createdAt: '2026-04-10T00:00:00',
    updatedAt: '2026-04-10T00:00:00',
  );
}

void main() {
  group('FlightSummaryService.generateFlightSummary', () {
    test('基本的なサマリーが生成される', () {
      final flight = _makeFlightRecord();
      final summary = FlightSummaryService.generateFlightSummary(
        flight: flight,
        aircraftName: 'JU-001 Mavic 3',
        pilotName: '石川 啓',
      );

      expect(summary, contains('【飛行記録】'));
      expect(summary, contains('FLT-0001'));
      expect(summary, contains('2026-04-10'));
      expect(summary, contains('JU-001 Mavic 3'));
      expect(summary, contains('石川 啓'));
      expect(summary, contains('30分'));
      expect(summary, contains('盛岡市内'));
      expect(summary, contains('点検業務'));
    });

    test('1時間以上の飛行時間が正しく表示される', () {
      final flight = _makeFlightRecord(flightDuration: 90);
      final summary = FlightSummaryService.generateFlightSummary(
        flight: flight,
      );

      expect(summary, contains('1時間30分'));
    });

    test('機体名・操縦者名が未指定の場合IDが表示される', () {
      final flight = _makeFlightRecord(aircraftId: 5, pilotId: 3);
      final summary = FlightSummaryService.generateFlightSummary(
        flight: flight,
      );

      expect(summary, contains('機体ID:5'));
      expect(summary, contains('操縦者ID:3'));
    });

    test('備考がある場合はサマリーに含まれる', () {
      final flight = _makeFlightRecord(notes: '風が強かった');
      final summary = FlightSummaryService.generateFlightSummary(
        flight: flight,
      );

      expect(summary, contains('備考: 風が強かった'));
    });

    test('備考が空の場合はサマリーに含まれない', () {
      final flight = _makeFlightRecord(notes: '');
      final summary = FlightSummaryService.generateFlightSummary(
        flight: flight,
      );

      expect(summary, isNot(contains('備考:')));
    });

    test('フッターが含まれる', () {
      final flight = _makeFlightRecord();
      final summary = FlightSummaryService.generateFlightSummary(
        flight: flight,
      );

      expect(summary, contains('ドローンログより出力'));
    });
  });

  group('FlightSummaryService.generatePeriodSummary', () {
    test('期間サマリーが正しく生成される', () {
      final flights = [
        _makeFlightRecord(id: 1, aircraftId: 1, pilotId: 1, flightDuration: 30),
        _makeFlightRecord(id: 2, aircraftId: 1, pilotId: 2, flightDuration: 45),
        _makeFlightRecord(id: 3, aircraftId: 2, pilotId: 1, flightDuration: 60),
      ];

      final summary = FlightSummaryService.generatePeriodSummary(
        flights: flights,
        startDate: '2026-04-01',
        endDate: '2026-04-10',
        aircraftNames: {1: 'JU-001', 2: 'JU-002'},
        pilotNames: {1: '石川', 2: '田中'},
      );

      expect(summary, contains('【飛行記録サマリー】'));
      expect(summary, contains('2026-04-01 ～ 2026-04-10'));
      expect(summary, contains('3回'));
      expect(summary, contains('2時間15分'));
      expect(summary, contains('JU-001'));
      expect(summary, contains('JU-002'));
      expect(summary, contains('石川'));
      expect(summary, contains('田中'));
    });

    test('飛行0件でもサマリーが生成される', () {
      final summary = FlightSummaryService.generatePeriodSummary(
        flights: [],
        startDate: '2026-04-01',
        endDate: '2026-04-10',
      );

      expect(summary, contains('0回'));
      expect(summary, contains('0時間0分'));
    });

    test('場所別集計が含まれる', () {
      final flights = [
        _makeFlightRecord(id: 1, takeoffLocation: '盛岡市'),
        _makeFlightRecord(id: 2, takeoffLocation: '盛岡市'),
        _makeFlightRecord(id: 3, takeoffLocation: '花巻市'),
      ];

      final summary = FlightSummaryService.generatePeriodSummary(
        flights: flights,
        startDate: '2026-04-01',
        endDate: '2026-04-10',
      );

      expect(summary, contains('盛岡市: 2回'));
      expect(summary, contains('花巻市: 1回'));
    });
  });
}
