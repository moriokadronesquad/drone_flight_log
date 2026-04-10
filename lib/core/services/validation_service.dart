/// 共通バリデーションサービス
/// 全フォームで使える再利用可能なバリデーション関数群
class ValidationService {
  // ─── 必須チェック ───

  /// 文字列が空でないことを確認する
  static String? requiredText(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldNameを入力してください';
    }
    return null;
  }

  /// ドロップダウン等の選択が行われていることを確認する
  static String? requiredSelection(Object? value, String fieldName) {
    if (value == null) {
      return '$fieldNameを選択してください';
    }
    return null;
  }

  // ─── 数値チェック ───

  /// 数値文字列が有効な数値であることを確認する
  static String? numericValue(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null; // 空は必須チェックに任せる
    if (double.tryParse(value.trim()) == null) {
      return '$fieldNameは数値で入力してください';
    }
    return null;
  }

  /// 数値が指定範囲内であることを確認する
  static String? numericRange(
    String? value,
    String fieldName, {
    double? min,
    double? max,
  }) {
    if (value == null || value.trim().isEmpty) return null;
    final num = double.tryParse(value.trim());
    if (num == null) {
      return '$fieldNameは数値で入力してください';
    }
    if (min != null && num < min) {
      return '$fieldNameは${min.toStringAsFixed(0)}以上で入力してください';
    }
    if (max != null && num > max) {
      return '$fieldNameは${max.toStringAsFixed(0)}以下で入力してください';
    }
    return null;
  }

  // ─── 日付・時刻チェック ───

  /// 日付文字列が有効であることを確認する（yyyy-MM-dd形式）
  static String? validDate(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      DateTime.parse(value.trim());
      return null;
    } catch (_) {
      return '$fieldNameの日付形式が正しくありません';
    }
  }

  /// 時刻文字列が有効であることを確認する（HH:mm形式）
  static String? validTime(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;
    final pattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
    if (!pattern.hasMatch(value.trim())) {
      return '$fieldNameの時刻形式が正しくありません（HH:mm）';
    }
    return null;
  }

  /// 終了時刻が開始時刻より後であることを確認する
  static String? timeAfter(
    String? startTime,
    String? endTime,
    String startLabel,
    String endLabel,
  ) {
    if (startTime == null ||
        startTime.trim().isEmpty ||
        endTime == null ||
        endTime.trim().isEmpty) {
      return null;
    }
    // HH:mm形式の比較（文字列比較で十分）
    if (endTime.trim().compareTo(startTime.trim()) <= 0) {
      return '$endLabelは$startLabelより後の時刻にしてください';
    }
    return null;
  }

  /// 終了日が開始日より後（または同日）であることを確認する
  static String? dateNotBefore(
    String? startDate,
    String? endDate,
    String startLabel,
    String endLabel,
  ) {
    if (startDate == null ||
        startDate.trim().isEmpty ||
        endDate == null ||
        endDate.trim().isEmpty) {
      return null;
    }
    if (endDate.trim().compareTo(startDate.trim()) < 0) {
      return '$endLabelは$startLabel以降の日付にしてください';
    }
    return null;
  }

  /// 日付が未来でないことを確認する（過去または今日のみ）
  static String? dateNotFuture(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final date = DateTime.parse(value.trim());
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final dateOnly = DateTime(date.year, date.month, date.day);
      if (dateOnly.isAfter(todayOnly)) {
        return '$fieldNameは今日以前の日付にしてください';
      }
      return null;
    } catch (_) {
      return '$fieldNameの日付形式が正しくありません';
    }
  }

  // ─── 文字列長チェック ───

  /// 最大文字数チェック
  static String? maxLength(String? value, String fieldName, int max) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length > max) {
      return '$fieldNameは$max文字以内で入力してください';
    }
    return null;
  }

  // ─── フォーマットチェック ───

  /// 機体登録番号の形式チェック（JUで始まる）
  static String? registrationNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim().toUpperCase();
    if (!trimmed.startsWith('JU') && !trimmed.startsWith('JA')) {
      return '登録番号はJUまたはJAで始まる番号を入力してください';
    }
    return null;
  }

  // ─── 複数エラーの一括チェック ───

  /// 複数のバリデーションを実行し、エラーリストを返す
  /// errorsが空なら全チェック通過
  static List<String> runAll(List<String? Function()> validators) {
    final errors = <String>[];
    for (final v in validators) {
      final result = v();
      if (result != null) {
        errors.add(result);
      }
    }
    return errors;
  }
}
