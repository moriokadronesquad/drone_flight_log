import 'package:flutter_test/flutter_test.dart';
import 'package:drone_flight_log/core/services/validation_service.dart';

void main() {
  group('ValidationService.requiredText', () {
    test('空文字列でエラーを返す', () {
      expect(ValidationService.requiredText('', '名前'), isNotNull);
      expect(ValidationService.requiredText('', '名前'), contains('名前'));
    });

    test('nullでエラーを返す', () {
      expect(ValidationService.requiredText(null, '名前'), isNotNull);
    });

    test('空白のみでエラーを返す', () {
      expect(ValidationService.requiredText('   ', '名前'), isNotNull);
    });

    test('値が入力済みならnullを返す', () {
      expect(ValidationService.requiredText('石川', '名前'), isNull);
    });
  });

  group('ValidationService.requiredSelection', () {
    test('nullでエラーを返す', () {
      expect(ValidationService.requiredSelection(null, '機体'), isNotNull);
    });

    test('値が選択済みならnullを返す', () {
      expect(ValidationService.requiredSelection(1, '機体'), isNull);
      expect(ValidationService.requiredSelection('マルチローター', '種別'), isNull);
    });
  });

  group('ValidationService.numericValue', () {
    test('空はnullを返す（必須チェックに任せる）', () {
      expect(ValidationService.numericValue('', '高度'), isNull);
      expect(ValidationService.numericValue(null, '高度'), isNull);
    });

    test('有効な数値はnullを返す', () {
      expect(ValidationService.numericValue('100', '高度'), isNull);
      expect(ValidationService.numericValue('3.14', '重量'), isNull);
      expect(ValidationService.numericValue('-5', '気温'), isNull);
    });

    test('数値でない文字列でエラーを返す', () {
      expect(ValidationService.numericValue('abc', '高度'), isNotNull);
      expect(ValidationService.numericValue('12a', '高度'), isNotNull);
    });
  });

  group('ValidationService.numericRange', () {
    test('範囲内はnullを返す', () {
      expect(
        ValidationService.numericRange('50', '高度', min: 0, max: 150),
        isNull,
      );
    });

    test('最小値未満でエラーを返す', () {
      expect(
        ValidationService.numericRange('-1', '高度', min: 0),
        isNotNull,
      );
    });

    test('最大値超過でエラーを返す', () {
      expect(
        ValidationService.numericRange('200', '高度', max: 150),
        isNotNull,
      );
    });

    test('境界値はnullを返す', () {
      expect(ValidationService.numericRange('0', '値', min: 0), isNull);
      expect(ValidationService.numericRange('150', '値', max: 150), isNull);
    });
  });

  group('ValidationService.validDate', () {
    test('有効な日付はnullを返す', () {
      expect(ValidationService.validDate('2026-04-10', '日付'), isNull);
    });

    test('無効な日付でエラーを返す', () {
      expect(ValidationService.validDate('2026/04/10', '日付'), isNotNull);
      expect(ValidationService.validDate('not-a-date', '日付'), isNotNull);
    });

    test('空はnullを返す', () {
      expect(ValidationService.validDate('', '日付'), isNull);
      expect(ValidationService.validDate(null, '日付'), isNull);
    });
  });

  group('ValidationService.validTime', () {
    test('有効な時刻はnullを返す', () {
      expect(ValidationService.validTime('09:30', '時刻'), isNull);
      expect(ValidationService.validTime('23:59', '時刻'), isNull);
      expect(ValidationService.validTime('00:00', '時刻'), isNull);
    });

    test('無効な時刻でエラーを返す', () {
      expect(ValidationService.validTime('25:00', '時刻'), isNotNull);
      expect(ValidationService.validTime('9:30', '時刻'), isNotNull);
      expect(ValidationService.validTime('abc', '時刻'), isNotNull);
    });
  });

  group('ValidationService.timeAfter', () {
    test('終了時刻が開始時刻より後ならnullを返す', () {
      expect(
        ValidationService.timeAfter('09:00', '10:00', '離陸', '着陸'),
        isNull,
      );
    });

    test('終了時刻が開始時刻以前ならエラーを返す', () {
      expect(
        ValidationService.timeAfter('10:00', '09:00', '離陸', '着陸'),
        isNotNull,
      );
    });

    test('同時刻でエラーを返す', () {
      expect(
        ValidationService.timeAfter('10:00', '10:00', '離陸', '着陸'),
        isNotNull,
      );
    });

    test('一方が空ならnullを返す', () {
      expect(ValidationService.timeAfter('', '10:00', '離陸', '着陸'), isNull);
      expect(ValidationService.timeAfter('09:00', '', '離陸', '着陸'), isNull);
    });
  });

  group('ValidationService.dateNotBefore', () {
    test('終了日が開始日以降ならnullを返す', () {
      expect(
        ValidationService.dateNotBefore('2026-04-01', '2026-04-10', '開始', '終了'),
        isNull,
      );
    });

    test('同日はnullを返す', () {
      expect(
        ValidationService.dateNotBefore('2026-04-10', '2026-04-10', '開始', '終了'),
        isNull,
      );
    });

    test('終了日が開始日より前ならエラーを返す', () {
      expect(
        ValidationService.dateNotBefore('2026-04-10', '2026-04-01', '開始', '終了'),
        isNotNull,
      );
    });
  });

  group('ValidationService.maxLength', () {
    test('制限内はnullを返す', () {
      expect(ValidationService.maxLength('abc', 'フィールド', 10), isNull);
    });

    test('制限超過でエラーを返す', () {
      expect(ValidationService.maxLength('a' * 11, 'フィールド', 10), isNotNull);
    });

    test('空はnullを返す', () {
      expect(ValidationService.maxLength('', 'フィールド', 10), isNull);
    });
  });

  group('ValidationService.registrationNumber', () {
    test('JUで始まる番号はnullを返す', () {
      expect(ValidationService.registrationNumber('JU-001'), isNull);
    });

    test('JAで始まる番号はnullを返す', () {
      expect(ValidationService.registrationNumber('JA-XXXX'), isNull);
    });

    test('小文字もOK（大文字変換される）', () {
      expect(ValidationService.registrationNumber('ju-001'), isNull);
    });

    test('JU/JA以外でエラーを返す', () {
      expect(ValidationService.registrationNumber('AB-001'), isNotNull);
    });

    test('空はnullを返す（必須チェックに任せる）', () {
      expect(ValidationService.registrationNumber(''), isNull);
    });
  });

  group('ValidationService.runAll', () {
    test('全チェック通過で空リストを返す', () {
      final errors = ValidationService.runAll([
        () => ValidationService.requiredText('テスト', '名前'),
        () => ValidationService.numericValue('100', '高度'),
      ]);
      expect(errors, isEmpty);
    });

    test('エラーがある場合はリストに含まれる', () {
      final errors = ValidationService.runAll([
        () => ValidationService.requiredText('', '名前'),
        () => ValidationService.numericValue('abc', '高度'),
      ]);
      expect(errors.length, equals(2));
    });
  });
}
