# ドローン飛行日誌

UAV（無人航空機）の飛行記録を管理するFlutter モバイルアプリケーション。

## 機能

### Phase 1: 機体・操縦者管理（実装完了）
- 航空機（ドローン）の登録・編集・削除
- パイロット情報の登録・編集・削除
- 登録情報の一覧表示

### Phase 2: 飛行記録管理（計画中）
- 飛行記録（日誌）の作成・編集
- 飛行ログの詳細情報管理
- 飛行データの検索・フィルタリング

### Phase 3: 飛行データ分析（計画中）
- 飛行時間などの統計情報
- グラフによるデータ分析
- 詳細レポート生成

## 技術スタック

- **フレームワーク**: Flutter 3.x
- **言語**: Dart 3.x
- **状態管理**: Riverpod
- **ルーティング**: GoRouter
- **ローカルDB**: Drift (SQLite)
- **UI**: Material Design 3

## セットアップ

### 前提条件
- Flutter SDK 3.2.0以上
- Dart 3.2.0以上

### インストール

1. プロジェクトディレクトリへ移動
```bash
cd drone_flight_log
```

2. 依存関係をインストール
```bash
flutter pub get
```

3. コード生成を実行
```bash
dart run build_runner build
```

4. アプリを実行
```bash
flutter run
```

## プロジェクト構成

```
lib/
├── main.dart                      # アプリケーションエントリーポイント
├── app.dart                       # アプリケーションルートウィジェット
├── core/
│   ├── constants/                 # アプリケーション定数
│   ├── database/                  # Driftデータベース定義
│   └── theme/                     # テーマ設定
├── features/
│   ├── aircraft/                  # 航空機管理機能
│   │   ├── data/                  # リポジトリ層
│   │   ├── domain/                # エンティティ
│   │   └── presentation/          # UI・状態管理
│   ├── pilot/                     # パイロット管理機能
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── home/                      # ホーム・ダッシュボード
├── routing/                       # ナビゲーション設定
└── shared/                        # 共有ウィジェット・ページ

test/
└── features/                      # ユニットテスト
```

## コーディング規約

- **型**: 型ヒント必須。`unknown`を使用。
- **コメント**: 日本語OK。関数の意図を記述。
- **テスト**: 新機能にはユニットテストを必須。
- **定数**: const コンストラクタを優先使用。

## データベース

SQLiteを使用したローカルデータベース。

### テーブル構成

**pilots（操縦者）**
- id: 主キー (自動採番)
- name: 名前
- licenseNumber: 免許証番号
- licenseType: 免許種類
- licenseExpiry: 免許有効期限
- organization: 所属組織
- contact: 連絡先
- createdAt: 作成日時
- updatedAt: 更新日時

**aircrafts（航空機）**
- id: 主キー (自動採番)
- registrationNumber: 登録番号（JU-***形式）
- aircraftType: 航空機タイプ
- manufacturer: 製造メーカー
- modelName: モデル名
- serialNumber: シリアルナンバー
- maxTakeoffWeight: 最大離陸重量
- totalFlightTime: 総飛行時間
- imageUrl: 画像URL
- createdAt: 作成日時
- updatedAt: 更新日時

## ビルドと実行

### 開発環境での実行
```bash
flutter run
```

### リリースビルド
```bash
flutter build apk      # Android
flutter build ios      # iOS
```

### テスト実行
```bash
flutter test
```

## ライセンス

Copyright 2024 DRONE PEAK Inc.

## サポート

問題が発生した場合は、GitHubのIssuesセクションで報告してください。
