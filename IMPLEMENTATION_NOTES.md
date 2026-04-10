# 実装詳細ドキュメント

## プロジェクト完成状況

合計28ファイル作成完了（Dartファイル22 + テスト1 + 設定ファイル5）

## ファイル一覧と説明

### 設定ファイル
- **pubspec.yaml** - パッケージ管理（Flutter 3.x, Riverpod, GoRouter, Drift）
- **analysis_options.yaml** - Lint設定（厳密な型チェック）
- **README.md** - セットアップガイド
- **.gitignore** - Git除外設定
- **PROJECT_SUMMARY.txt** - プロジェクト概要

### コアモジュール

#### 1. エントリーポイント
- `lib/main.dart` - ProviderScopeの初期化
- `lib/app.dart` - MaterialApp.routerの設定

#### 2. テーマ・UI
- `lib/core/theme/app_theme.dart` - Material 3テーマ（青#1A73E8、緑#34A853）
- `lib/core/constants/app_constants.dart` - 定数管理

#### 3. データベース
- `lib/core/database/app_database.dart` - Drift DBの完全実装
  - Pilotsテーブル（操縦者情報）
  - Aircraftsテーブル（航空機情報）
  - CRUD操作の全実装
- `lib/core/database/app_database.g.dart` - コード生成プレースホルダー

### 機能モジュール

#### 航空機管理（Aircraft）
- **Domain層**: `aircraft.dart` - 不変エンティティ
- **Data層**: `aircraft_repository.dart` - リポジトリ実装
- **Presentation層**:
  - `aircraft_provider.dart` - Riverpod状態管理
  - `aircraft_list_page.dart` - 一覧表示（PopupMenu削除機能）
  - `aircraft_form_page.dart` - 新規/編集フォーム（JU-プレフィックス検証）

#### 操縦者管理（Pilot）
- **Domain層**: `pilot.dart` - 不変エンティティ
- **Data層**: `pilot_repository.dart` - リポジトリ実装
- **Presentation層**:
  - `pilot_provider.dart` - Riverpod状態管理
  - `pilot_list_page.dart` - 一覧表示
  - `pilot_form_page.dart` - 登録/編集フォーム（日付ピッカー対応）

#### ホーム（Home）
- `home_page.dart` - ダッシュボード
  - 統計情報カード（機体数、操縦者数）
  - クイックアクション（Phase 3表記）
  - フェーズ進捗表示

### ナビゲーション・UI
- `lib/routing/app_router.dart` - GoRouter設定（ShellRoute + BottomNav）
- `lib/shared/widgets/bottom_nav_scaffold.dart` - ナビゲーション実装
- `lib/shared/widgets/empty_state_widget.dart` - 空状態UI
- `lib/shared/widgets/confirm_dialog.dart` - 確認ダイアログ
- `lib/shared/pages/settings_page.dart` - 設定ページ

### テスト
- `test/features/aircraft/aircraft_repository_test.dart`
  - MockitoによるMock実装例
  - リポジトリの基本テスト

## 技術的な実装ポイント

### 1. Driftデータベース
```dart
// Drift仕様に従い、手動実装（コード生成非依存）
- LazyDatabaseで遅延初期化
- getApplicationDocumentsDirectoryで永続化
- await/Future対応のCRUD操作
```

### 2. Riverpod状態管理
```dart
// 宣言的な状態管理
- StreamProvider: リアルタイム更新対応
- StateNotifierProvider: フォーム状態管理
- Provider: 単純な依存注入
```

### 3. GoRouterルーティング
```dart
// シェルルートでボトムナビ実装
- ShellRoute: 共通UI（BottomNavigationBar）
- 4つのタブ: ホーム、機体、操縦者、設定
- パスパラメータで編集画面のID指定
```

### 4. UI/UXの実装
- **Material Design 3**: テーマ統一
- **日本語対応**: locale設定済み
- **エラーハンドリング**: SnackBar表示
- **ローディング状態**: CircularProgressIndicator表示
- **バリデーション**: 登録番号（JU-形式）の検証

### 5. コーディング規約準拠
```dart
✅ 型ヒント必須: すべての関数に明示的な戻り値型
✅ 日本語コメント: 「何をする」という意図を記述
✅ const優先: const constructorを最大限活用
✅ エラーハンドリング: 空のtry-catchなし
```

## アーキテクチャ

```
層別構成
┌─────────────────────────┐
│   Presentation層        │
│  Pages / Providers      │
├─────────────────────────┤
│   Domain層              │
│  Entities / Use Cases   │
├─────────────────────────┤
│   Data層                │
│  Repositories / DB      │
└─────────────────────────┘

フローの例（航空機登録）
1. AircraftFormPageでユーザー入力
2. aircraftFormProvider.notifierで処理
3. AircraftRepositoryでDB操作
4. AppDatabase.createAircraftでSQL実行
5. StreamProviderでリアルタイム更新
6. AircraftListPageで反映
```

## データベーススキーマ

### pilotsテーブル
```sql
CREATE TABLE pilots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  licenseNumber TEXT,
  licenseType TEXT,        -- '一等'/'二等'/'なし'
  licenseExpiry TEXT,      -- ISO8601形式
  organization TEXT,
  contact TEXT,
  createdAt TEXT NOT NULL, -- ISO8601形式
  updatedAt TEXT NOT NULL
)
```

### aircraftsテーブル
```sql
CREATE TABLE aircrafts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  registrationNumber TEXT UNIQUE NOT NULL, -- 'JU-*'形式
  aircraftType TEXT NOT NULL,              -- マルチローター/固定翼/VTOL/その他
  manufacturer TEXT,
  modelName TEXT,
  serialNumber TEXT,
  maxTakeoffWeight REAL,                   -- kg単位
  totalFlightTime INTEGER DEFAULT 0,       -- 分単位
  imageUrl TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
```

## デバッグ・開発時の注意点

### コード生成
```bash
# 初回セットアップ後に必須
dart run build_runner build

# 変更検出時
dart run build_runner watch
```

### データベースリセット
```bash
# アプリをアンインストール、または
# getApplicationDocumentsDirectory内の
# drone_flight_log.dbを削除
```

### Lintエラー確認
```bash
flutter analyze
```

## 今後の拡張ポイント

### Phase 2対応
- Flightテーブルの追加（飛行記録）
- 飛行時間の自動計算
- 飛行データ（時間、距離、位置情報等）の管理

### Phase 3対応
- グラフ表示（charts_flutter）
- レポート生成
- データ分析機能
- エクスポート機能

## トラブルシューティング

### ビルドエラー
- `flutter clean`を実行
- `flutter pub get`を再実行
- `dart run build_runner build`を実行

### ホットリロード不可
- ファイルを保存後、rキー押下で再実行

### データベース接続エラー
- アプリを完全に再起動（アンインストール+再インストール）

