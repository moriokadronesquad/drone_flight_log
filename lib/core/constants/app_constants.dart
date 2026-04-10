/// アプリケーション全体で使用される定数
class AppConstants {
  // アプリ情報
  static const String appName = 'ドローン飛行日誌';
  static const String appVersion = '1.0.0';

  // ドローンの種類
  static const List<String> aircraftTypes = [
    'マルチローター',
    '固定翼',
    'VTOL',
    'その他',
  ];

  // パイロットライセンスの種類
  static const List<String> licenseTypes = [
    '一等',
    '二等',
    'なし',
  ];

  // 登録番号のプレフィックス検証用
  static const String aircraftRegistrationPrefix = 'JU';

  // データベースファイル名
  static const String databaseFileName = 'drone_flight_log.db';

  // 日付フォーマット
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm';

  // フェーズ情報
  static const String phase1Name = 'Phase 1: 機体・操縦者管理';
  static const String phase2Name = 'Phase 2: 飛行記録管理';
  static const String phase3Name = 'Phase 3: 飛行管理・分析';
}
