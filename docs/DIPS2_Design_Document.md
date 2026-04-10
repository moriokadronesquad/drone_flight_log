# DIPS 2.0 API 連携 設計書

**プロジェクト**: ドローンログ（Flutter Web）
**作成日**: 2026年4月6日
**対象**: 国土交通省 DIPS 2.0 API（FPR）v1.9
**作成者**: Claude / DRONE PEAK

---

## 1. 概要

### 1.1 目的

ドローンログアプリに国土交通省の DIPS 2.0 API（FPR: Flight Plan Report）を統合し、以下の機能を実現する。

- **機体情報一覧取得**: DIPS に登録済みの機体情報を一括取得
- **許可・承認情報取得**: 飛行に必要な許可・承認の申請状況を確認
- **許可・承認申請受付**: 飛行許可・承認の申請をアプリから直接提出
- **飛行計画通報**: アプリから直接 DIPS に飛行計画を通報（登録・更新）
- **飛行計画検索**: 自分と他ユーザーの飛行計画を地図上で確認
- **飛行禁止エリア確認**: 飛行予定エリアの禁止区域を事前チェック

### 1.2 システム構成

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  ドローンログ    │     │  さくらVPS (固定IP)     │     │  DIPS 2.0 API   │
│  (Flutter Web)   │────▶│  FastAPI Proxy        │────▶│  (国土交通省)     │
│  GitHub Pages    │◀────│  Python 3.11 / Docker │◀────│  OpenID Connect │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
                              │
                        ┌─────┴──────┐
                        │ トークン     │
                        │ 暗号化保管   │
                        └────────────┘
```

**なぜ Proxy が必要か**: Flutter Web（GitHub Pages）はブラウザ上で動作するため、以下の制約がある。

- CORS制限: ブラウザから DIPS API に直接リクエストできない
- シークレット保護: client_secret をフロントエンドに埋め込めない
- トークン管理: サーバーサイドでの安全なトークン保管が必要
- **固定IP要件**: 国交省から固定IPが必須と回答あり（GASはGoogle動的IPのため不可）

さくらVPS（512MBプラン / 月590円）+ FastAPI で Proxy を構築し、これらの問題をすべて解決する。

> **アーキテクチャ変更（2026-04-08決定）**: 当初はGAS Proxyを予定していたが、固定IP要件によりさくらVPS + FastAPIに変更。GASは既存のスプレッドシート連携に引き続き使用し、DIPS連携のみVPSで処理する。

### 1.3 前提条件

- DIPS 2.0 API 利用申請が必要（国土交通省 航空局 安全部 無人航空機安全課へ申請）
- 申請先メール: hqt-jcab.mujin@ki.mlit.go.jp
- client_id / client_secret の発行を受ける必要がある
- まず検証環境で動作確認 → 完了報告 → 本番環境の利用開始

---

## 2. 認証フロー設計

### 2.1 OpenID Connect Authorization Code Flow

DIPS 2.0 API は OpenID Connect の認可コードフローを使用する。

```
ユーザー        ドローンログ       GAS Proxy        DIPS 認証サーバー
  │                │                  │                    │
  │ ①「DIPS連携」   │                  │                    │
  │  ボタンをクリック │                  │                    │
  │───────────────▶│                  │                    │
  │                │ ②認可URLを生成    │                    │
  │                │  (state含む)     │                    │
  │                │─────────────────▶│                    │
  │                │  認可URLを返却    │                    │
  │                │◀─────────────────│                    │
  │◀───────────────│                  │                    │
  │ ③DIPSログイン画面                   │                    │
  │  にリダイレクト   │                  │                    │
  │────────────────────────────────────────────────────────▶│
  │                │                  │                    │
  │ ④ ID/パスワード入力                  │                    │
  │────────────────────────────────────────────────────────▶│
  │                │                  │                    │
  │◀────────────────────────────────────────────────────────│
  │ ⑤認可コード付き                     │                    │
  │  redirect_uriへ │                  │                    │
  │───────────────▶│                  │                    │
  │                │ ⑥認可コードを     │                    │
  │                │  GASに送信       │                    │
  │                │─────────────────▶│                    │
  │                │                  │ ⑦トークン取得        │
  │                │                  │───────────────────▶│
  │                │                  │◀───────────────────│
  │                │                  │  access_token      │
  │                │                  │  refresh_token     │
  │                │                  │  id_token          │
  │                │ ⑧認証成功を返却   │                    │
  │                │◀─────────────────│                    │
  │◀───────────────│                  │                    │
  │ ⑨「DIPS連携完了」                   │                    │
```

### 2.2 エンドポイント一覧

| 用途 | 本番環境 | 検証環境 |
|------|---------|---------|
| 認可 | `https://www.dips-reg.mlit.go.jp/auth/realms/drs-fpl/protocol/openid-connect/auth` | `https://www.stg.uafp.dips.mlit.go.jp/auth/realms/drs-fpl/protocol/openid-connect/auth` |
| トークン | 同上ベース + `/token` | 同上ベース + `/token` |
| UserInfo | 同上ベース + `/userinfo` | 同上ベース + `/userinfo` |
| 機体情報一覧取得 | `https://www.uafpi.dips.mlit.go.jp/api/aircraft/list` | `https://www.stg.uafpi.dips.mlit.go.jp/api/aircraft/list` |
| 許可・承認情報取得 | `https://www.uafpi.dips.mlit.go.jp/api/permit-application/search` | `https://www.stg.uafpi.dips.mlit.go.jp/api/permit-application/search` |
| 許可・承認申請受付 | `https://www.uafpi.dips.mlit.go.jp/api/permit-application/register` | `https://www.stg.uafpi.dips.mlit.go.jp/api/permit-application/register` |
| 飛行計画検索 | `https://www.uafpi.dips.mlit.go.jp/api/flight-plan/search` | `https://www.stg.uafpi.dips.mlit.go.jp/api/flight-plan/search` |
| 飛行禁止エリア | `https://www.uafpi.dips.mlit.go.jp/api/flight-prohibited-area/search` | `https://www.stg.uafpi.dips.mlit.go.jp/api/flight-prohibited-area/search` |
| 飛行計画通報 | `https://www.uafpi.dips.mlit.go.jp/api/flight-plan/register` | `https://www.stg.uafpi.dips.mlit.go.jp/api/flight-plan/register` |

### 2.3 トークン管理

| トークン | 有効期間 | 用途 |
|---------|---------|------|
| access_token | 300秒（5分） | API呼び出し時の認証ヘッダー |
| refresh_token | 3600秒（1時間） | access_token の更新 |
| id_token | JWT形式 | ユーザー情報の検証 |

**トークンの保管場所**: さくらVPS上に Fernet 暗号化ファイル (`data/tokens.enc`) として保管し、フロントエンドには一切返さない。プロセス再起動時にも認証状態を維持する。

**自動更新ロジック**: FastAPI Proxy 内で API 呼び出し前に access_token の有効期限をチェックし、期限切れの場合は refresh_token で自動更新する（`DipsClient._ensure_valid_token()`）。

### 2.4 id_token の検証項目

| No | 検証内容 |
|----|--------|
| 1 | iss（発行者）が DIPS の認証サーバー URL と一致すること |
| 2 | aud（受け取り者）が自社の client_id と一致すること |
| 3 | exp（有効期限）が現在時刻より後であること |
| 4 | iat（発行時刻）が現在時刻より前で、古すぎないこと |
| 5 | auth_time（認証時刻）が現在時刻より前で、古すぎないこと |

---

## 3. API 機能設計

### 3.1 機体情報一覧取得 API

**目的**: DIPSに登録されている自分の機体情報を一覧取得し、飛行計画通報時の機体選択に利用する

**メソッド**: GET（※詳細パスはAPI設定通知書で確認）
**パス**: `/api/aircraft/list`（推定）

> **注意**: このAPIの詳細仕様（リクエスト/レスポンスの全パラメータ）は、DIPS 2.0 API利用申請承認後に配布される「API設定通知書」に記載されます。以下はFPRガイドラインの飛行計画通報API内の aircraftInfo フィールドから推定した項目です。

**レスポンス（推定フィールド）**:

| フィールド | 説明 |
|----------|------|
| aircraftId | 機体ID（DIPS登録番号） |
| symbol | 機体の登録記号 |
| maker | メーカー名 |
| model | 機体型式名 |
| type | 機体種類（1=飛行機, 3=マルチローター 等） |
| maxWeight | 最大離陸重量（kg） |
| serialNumber | 製造番号 |
| registrationNumber | 機体登録番号 |

**アプリとの連携**:

- 取得した機体一覧をアプリの「機体マスタ」と自動同期可能
- 飛行計画通報フォームの Step 4 で DIPS 登録済み機体をプルダウン選択
- アプリ未登録の機体があれば、機体マスタへの追加を提案

---

### 3.2 許可・承認情報取得 API

**目的**: DIPSに登録されている飛行許可・承認の申請情報を取得する

**メソッド**: POST（※詳細パスはAPI設定通知書で確認）
**パス**: `/api/permit-application/search`（推定）

> **注意**: このAPIの詳細仕様は「API設定通知書」に記載されます。以下はFPRガイドラインの飛行計画通報API内の flightPermitApplicationInfo フィールドから推定した項目です。

**レスポンス（推定フィールド）**:

| フィールド | 説明 |
|----------|------|
| permitApplicationId | 許可・承認申請ID |
| applicationNumber | 申請番号 |
| approvalNumber | 許可・承認番号 |
| approvalDate | 許可書発行日 |
| startDate | 許可期間（開始） |
| endDate | 許可期間（終了） |
| flightAirspace | 許可された飛行空域 |
| flightType | 許可された飛行方法 |
| status | 申請状態（申請中/承認済/差戻し 等） |

**アプリとの連携**:

- 飛行計画通報時に、有効な許可・承認情報を自動選択
- 許可期間の残日数をアラート表示
- 飛行空域・方法と許可内容の整合性を自動チェック

---

### 3.3 許可・承認申請受付 API

**目的**: 飛行許可・承認の申請をアプリから直接DIPSに提出する

**メソッド**: POST（※詳細パスはAPI設定通知書で確認）
**パス**: `/api/permit-application/register`（推定）

> **注意**: このAPIの詳細仕様は「API設定通知書」に記載されます。以下はFPRガイドラインの関連情報から推定した項目です。

**リクエストパラメータ（推定）**:

| No | 項目 | パラメータ | 必須 | 説明 |
|----|------|----------|------|------|
| 1 | 飛行空域 | flightAirspace | O | 申請する飛行空域（DID上空/150m以上/空港周辺） |
| 2 | 飛行方法 | flightType | O | 申請する飛行方法（30m未満/夜間/目視外 等） |
| 3 | 飛行目的 | flightPurpose | O | 飛行目的コード |
| 4 | 飛行予定期間 | startDate / endDate | O | 許可を申請する期間 |
| 5 | 飛行予定場所 | flightArea | O | 飛行エリア情報 |
| 6 | 機体情報 | aircraftInfo | O | 使用機体の情報 |
| 7 | 操縦者情報 | pilotInfo | O | 操縦者の技能情報 |
| 8 | 安全対策 | safetyMeasures | O | 安全確保の措置内容 |
| 9 | 保険情報 | insuranceInformation | O | 賠償責任保険の情報 |
| 10 | 申請者情報 | applicantInfo | O | 申請者の連絡先情報 |

**レスポンス（推定）**:

| フィールド | 説明 |
|----------|------|
| permitApplicationId | 採番された申請ID |
| applicationResult | 受付結果（"受付完了" 等） |
| applicationDatetime | 受付日時 |

**アプリとの連携**:

- 飛行計画通報フォームの Step 5 で「許可が必要な飛行」と判定された場合、許可申請画面に遷移
- 申請状態を一覧画面でトラッキング（申請中→審査中→承認/差戻し）
- 承認済みの許可情報は飛行計画通報時に自動紐付け

---

### 3.4 飛行計画情報取得 API

**目的**: 指定エリア・期間の飛行計画を検索する（自分のもの＋他ユーザーのもの）

**メソッド**: POST
**パス**: `/api/flight-plan/search`

**リクエストパラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|----------|------|------|------|
| features.type | 文字列 | O | Circle（円）/ Polygon（多角形） |
| features.center | 配列 | 条件付 | Circle時の中心点 [経度, 緯度] |
| features.radius | 数値 | 条件付 | Circle時の半径（メートル） |
| features.coordinates | 配列 | 条件付 | Polygon時の構成点 [[経度,緯度]...] |
| allFlightPlan | 文字列 | - | "1": 自分のみ、"0": 全ユーザー |
| startTime | 文字列 | - | 検索開始時刻（yyyyMMdd HHmm） |
| finishTime | 文字列 | - | 検索終了時刻（yyyyMMdd HHmm） |
| updateTime | 文字列 | - | 更新時刻フィルター |

**レスポンス（主要フィールド）**:

| フィールド | 説明 |
|----------|------|
| flightPlanId | 飛行計画ID |
| name | 飛行計画名称 |
| flightPurpose | 飛行目的（配列: 1=空撮, 5=測量, 8=インフラ点検 等） |
| flightAirspace | 飛行空域（1=DID上空, 2=150m以上, 3=空港周辺） |
| flightType | 飛行方法（1=30m未満, 2=催し物上空, 3=夜間, 4=目視外 等） |
| startTime / finishTime | 飛行開始・終了日時 |
| flyRoute | 飛行経路（Circle/Polygon のジオメトリ情報） |
| pilotInfo | 操縦者情報 |
| aircraftInfo | 機体情報 |
| flightPermitApplicationInfo | 許可・承認情報 |

### 3.5 飛行禁止エリア情報取得 API

**目的**: 飛行予定エリアの禁止区域をチェックする

**メソッド**: POST
**パス**: `/api/flight-prohibited-area/search`

**リクエストパラメータ**:

| パラメータ | 型 | 必須 | 説明 |
|----------|------|------|------|
| features.type | 文字列 | O | Circle / Polygon |
| features.center | 配列 | 条件付 | Circle時の中心点 |
| features.radius | 数値 | 条件付 | Circle時の半径（メートル） |
| features.coordinates | 配列 | 条件付 | Polygon時の構成点 |
| flightProhibitedAreaInfo | - | O | 禁止エリア種別フィルター |
| flightProhibitedAreaTypeId | 配列 | O | エリア種別（下記参照） |
| startTime / finishTime | 文字列 | - | 検索期間 |
| updateTime | 文字列 | - | 更新時刻フィルター |

**飛行禁止エリア種別**:

| コード | 種別 |
|-------|------|
| 1 | 空港等の周辺空域 |
| 2 | 人口集中地区（DID） |
| 5 | 小型無人機等飛行禁止法で定めるエリア（レッドゾーン） |
| 6 | 同上（イエローゾーン） |
| 7 | 条例等で定めるエリア |
| 8 | 有人機離着陸エリア |
| 9 | 緊急時用務空域 |
| 10 | その他1 |
| 11 | その他2 |

**レスポンス**:

| フィールド | 説明 |
|----------|------|
| flightProhibitedAreaId | 禁止エリアID |
| name | エリア名称 |
| range | エリア範囲（Circle/Polygon ジオメトリ） |
| detail | 説明詳細 |
| url | 説明URL |
| flightProhibitedAreaTypeId | エリア種別 |
| startTime / finishTime | 有効期間 |

### 3.6 飛行計画通報受付 API

**目的**: 飛行計画をDIPSに通報（新規登録・更新）する

**メソッド**: POST
**パス**: `/api/flight-plan/register`

**リクエストパラメータ（主要項目）**:

| No | 項目 | パラメータ | 必須 | 説明 |
|----|------|----------|------|------|
| 1 | 飛行計画ID | flightPlanId | 更新時必須 | 新規は空欄、更新時は既存ID |
| 2 | 飛行計画名称 | name | O | 任意の名称（最大30文字） |
| 3 | 飛行目的 | flightPurpose | O | 配列（複数選択可） |
| 4 | 飛行空域 | flightAirspace | - | 1=DID, 2=150m以上, 3=空港周辺 |
| 5 | 飛行方法 | flightType | - | 1=30m未満, 2=催し物上空 等 |
| 6 | 補助者数 | assistantsNumber | O | 0以上の整数 |
| 7 | 出発地 | departurePoint | O | 地名・固有名称 |
| 8 | 飛行開始日時 | startTime | O | yyyyMMdd hhmm 形式 |
| 9 | 航続可能時間 | plannedMaxTime | O | 分（5分単位, 5〜1440） |
| 10 | 所要時間 | plannedFlightTime | O | 分（5分単位, 5〜1440） |
| 11 | 飛行速度 | flightSpeed | O | km/h（1〜999） |
| 12 | 飛行高度 | flightAltitude | O | メートル/AGL（1〜999） |
| 13 | 飛行経路 | flyRoute | O | GeoJSON形式の文字列 |
| 14 | 目的地 | destinationPoint | O | 地名・固有名称 |
| 15 | 立入管理措置 | riskMitigationOnsiteControl | O | "1"=講じる, "0"=講じない |
| 16 | 係留飛行 | exceptionalConditionsMooring | O | "1"=する, "0"=しない |
| 17 | 保険情報 | insuranceInformation | 条件付 | 許可・承認設定時は必須 |
| 18 | 通報者 | reporter | O | 連絡先情報 |
| 19 | 操縦者情報 | pilotInfo | O | 配列 |
| 20 | 機体情報 | aircraftInfo | O | 配列 |
| 21 | 許可・承認情報 | flightPermitApplicationInfo | 条件付 | 許可が必要な飛行の場合 |

**飛行目的コード一覧**:

| コード | 目的 |
|-------|------|
| 1 | 空撮 |
| 2 | 報道取材 |
| 3 | 警備 |
| 4 | 農林水産業 |
| 5 | 測量 |
| 6 | 環境調査 |
| 7 | 設備メンテナンス |
| 8 | インフラ点検・保守 |
| 9 | 資材管理 |
| 10 | 輸送・宅配 |
| 11 | 自然観測 |
| 12 | 事故・災害対応等 |
| 13 | その他1（業務） |
| 14 | 趣味 |
| 15 | 研究開発 |
| 16 | その他2（業務以外） |

**レスポンス**:

| フィールド | 説明 |
|----------|------|
| flightPlanId | 採番されたID |
| flightPlanRegistrationResult | 登録結果（"登録完了" 等） |
| flightPlanRegistrationDatetime | 受付日時 |
| existOtherFlightRoutesCount | 重複する飛行経路の件数 |
| duplicateFlightPlan | 重複計画の詳細（10件以内なら全情報） |

**エラーコード**: 400（パラメータ不正）、500（システムエラー）

---

## 4. 実装計画

### 4.1 フェーズ構成

| フェーズ | 内容 | 優先度 |
|---------|------|--------|
| Phase A | DIPS 2.0 API 利用申請 | 最優先 |
| Phase B | GAS Proxy 実装（認証＋API中継） | 高 |
| Phase C | Flutter 側 DIPS 連携画面 | 高 |
| Phase D | 飛行計画通報フォーム | 高 |
| Phase E | 飛行禁止エリア地図表示 | 中 |
| Phase F | 検証環境テスト＆本番移行 | 高 |

### 4.2 Phase A: DIPS 2.0 API 利用申請

1. 国土交通省のドキュメントダウンロードページから以下を取得
   - 接続システム向けガイドライン（本PDF）
   - DIPS 2.0 API 利用申請書
   - 利用規約、プライバシーポリシー
2. 利用申請書に記入して `hqt-jcab.mujin@ki.mlit.go.jp` へ提出
3. 検証環境用の client_id / client_secret を受領
4. DIPS 2.0 API 設定通知書を受領

### 4.3 Phase B: GAS Proxy 実装

**新規 GAS ファイル**: `07_dips_api.gs`

```
GAS Proxy の機能:
├── 認証管理
│   ├── getAuthUrl()        → DIPS認可URLを生成して返す
│   ├── handleCallback()    → 認可コードでトークンを取得・保存
│   ├── refreshToken()      → access_tokenを自動更新
│   └── checkDipsAuth()     → DIPS連携状態の確認
│
├── API中継
│   ├── getAircraftList()      → 機体情報一覧取得を中継
│   ├── searchPermitApplication() → 許可・承認情報取得を中継
│   ├── registerPermitApplication() → 許可・承認申請受付を中継
│   ├── searchFlightPlan()     → 飛行計画検索を中継
│   ├── searchProhibitedArea() → 飛行禁止エリア検索を中継
│   └── registerFlightPlan()   → 飛行計画通報を中継
│
└── データ変換
    ├── buildFlightPlanRequest()  → アプリデータ→API形式に変換
    └── parseFlightPlanResponse() → APIレスポンス→アプリ形式に変換
```

**トークン保管**: GAS の `PropertiesService.getScriptProperties()` に以下を保存

| キー | 内容 |
|------|------|
| DIPS_CLIENT_ID | クライアントID |
| DIPS_CLIENT_SECRET | クライアントシークレット |
| DIPS_ACCESS_TOKEN | アクセストークン |
| DIPS_REFRESH_TOKEN | リフレッシュトークン |
| DIPS_TOKEN_EXPIRY | トークン有効期限（UNIX時刻） |
| DIPS_ENV | "stg" or "prod" |

### 4.4 Phase C: Flutter 側 DIPS 連携画面

**新規ファイル構成**:

```
lib/features/dips/
├── data/
│   └── dips_api_service.dart        # GAS Proxy経由のAPI呼び出し
├── domain/
│   ├── models/
│   │   ├── flight_plan.dart         # 飛行計画モデル
│   │   ├── prohibited_area.dart     # 飛行禁止エリアモデル
│   │   ├── aircraft_info.dart       # 機体情報モデル
│   │   ├── permit_application.dart  # 許可・承認情報モデル
│   │   └── dips_auth_status.dart    # DIPS認証状態モデル
│   └── enums/
│       ├── flight_purpose.dart      # 飛行目的（16種）
│       ├── flight_airspace.dart     # 飛行空域（3種）
│       ├── flight_type.dart         # 飛行方法（6種）
│       ├── prohibited_area_type.dart # 禁止エリア種別
│       └── prefecture_code.dart     # 都道府県コード
├── presentation/
│   ├── providers/
│   │   ├── dips_auth_provider.dart  # DIPS認証状態管理
│   │   ├── aircraft_provider.dart   # 機体情報データ管理
│   │   ├── permit_provider.dart     # 許可・承認データ管理
│   │   ├── flight_plan_provider.dart # 飛行計画データ管理
│   │   └── prohibited_area_provider.dart # 禁止エリアデータ管理
│   └── pages/
│       ├── dips_connection_page.dart # DIPS連携設定画面
│       ├── aircraft_list_page.dart   # DIPS機体一覧画面
│       ├── permit_list_page.dart     # 許可・承認一覧画面
│       ├── permit_application_page.dart # 許可・承認申請画面
│       ├── flight_plan_form_page.dart # 飛行計画通報フォーム
│       ├── flight_plan_search_page.dart # 飛行計画検索画面
│       └── prohibited_area_page.dart # 禁止エリア確認画面
└── utils/
    ├── geo_json_helper.dart          # GeoJSON生成ヘルパー
    └── dips_code_converter.dart      # コード変換ユーティリティ
```

### 4.5 Phase D: 飛行計画通報フォーム

アプリ内の飛行記録データと DIPS API のパラメータをマッピングする。

**アプリ既存データ → DIPS パラメータ マッピング**:

| アプリ内データ | DIPS パラメータ | 変換方法 |
|-------------|-------------|---------|
| 飛行記録.飛行日 | startTime | 日付形式を "yyyyMMdd hhmm" に変換 |
| 飛行記録.離陸場所 | departurePoint | そのまま |
| 飛行記録.着陸場所 | destinationPoint | そのまま |
| 機体マスタ.登録番号 | aircraftInfo.symbol | そのまま |
| 機体マスタ.メーカー | aircraftInfo.maker | そのまま |
| 機体マスタ.型式 | aircraftInfo.model | そのまま |
| 機体マスタ.機体種別 | aircraftInfo.type | "回転翼"→"3", "固定翼"→"1" 等 |
| 機体マスタ.最大離陸重量 | aircraftInfo.maxWeight | kg単位 |
| 操縦者マスタ.氏名 | pilotInfo.contactPilot.name | そのまま |
| 操縦者マスタ.技能証明番号 | pilotInfo.skillCertificationNumber | そのまま |
| 設定.連絡先メール | reporter.contactReporter.email | そのまま |

**フォーム画面のステップ構成（ウィザード形式）**:

```
Step 1: 基本情報
  ├── 飛行計画名称（テキスト入力）
  ├── 飛行目的（複数チェックボックス: 16種から選択）
  ├── 出発地 / 目的地（テキスト入力、アプリの場所データから補完）
  └── 飛行日時（日付・時刻ピッカー）

Step 2: 飛行条件
  ├── 飛行空域（チェックボックス: DID上空/150m以上/空港周辺）
  ├── 飛行方法（チェックボックス: 30m未満/催し物上空/夜間/目視外/危険物/物件投下）
  ├── 飛行速度 / 飛行高度（数値入力）
  ├── 航続可能時間 / 所要時間（分単位、5分刻み）
  └── 補助者数（数値入力）

Step 3: 飛行エリア
  ├── 地図上で飛行エリアを指定
  │   ├── 円（Circle）: 中心点タップ + 半径入力
  │   └── 多角形（Polygon）: 頂点をタップで指定
  ├── 立入管理措置（あり/なし）
  └── 係留飛行（する/しない）

Step 4: 機体・操縦者
  ├── 使用機体の選択（マスタから）
  ├── 操縦者の選択（マスタから）
  └── 保険情報の入力

Step 5: 許可・承認情報（該当する場合）
  ├── 許可・承認番号
  ├── 許可書発行日
  └── 許可期間（自〜至）

Step 6: 通報者情報
  ├── 氏名 / 住所 / 電話番号 / メールアドレス
  └── 連絡先フラグの選択（通報者/操縦者/許可承認者）

Step 7: 確認・送信
  ├── 入力内容の最終確認
  ├── 禁止エリアとの重複チェック結果表示
  └── 「通報する」ボタン
```

### 4.6 Phase E: 飛行禁止エリア地図表示

飛行計画通報の Step 3 と連動し、指定した飛行エリアに禁止区域が含まれていないか自動チェックする。

**表示要素**:

| エリア種別 | 地図上の色 |
|----------|---------|
| 空港等の周辺空域 | 赤（Red） |
| 人口集中地区（DID） | オレンジ（Orange） |
| レッドゾーン | 赤（Red、点線） |
| イエローゾーン | 黄（Yellow） |
| 条例等エリア | 紫（Purple） |
| 緊急時用務空域 | グレー（Grey） |

### 4.7 Phase F: テスト＆本番移行

**検証環境での確認ポイント**:

| カテゴリ | 確認内容 |
|---------|---------|
| OpenID Connect | 認可リクエスト後、指定 redirect_uri にリダイレクトされること |
| OpenID Connect | state の値がリクエストとレスポンスで一致すること |
| OpenID Connect | 認可コードでアクセストークンが取得できること |
| OpenID Connect | id_token の検証が正常に行えること |
| OpenID Connect | アクセストークンで属性情報が取得できること |
| 機体情報一覧取得 | リクエスト/レスポンスが設定通知書の仕様通りであること |
| 許可・承認情報取得 | リクエスト/レスポンスが設定通知書の仕様通りであること |
| 許可・承認申請受付 | リクエスト/レスポンスが設定通知書の仕様通りであること |
| 飛行計画検索 | リクエスト/レスポンスが設定通知書の仕様通りであること |
| 飛行禁止エリア | リクエスト/レスポンスが設定通知書の仕様通りであること |
| 飛行計画通報 | リクエスト/レスポンスが設定通知書の仕様通りであること |

**本番移行の流れ**:

1. 検証環境動作確認完了報告を国土交通省へ提出
2. 本番環境用の client_id / client_secret を受領
3. GAS の DIPS_ENV を "prod" に切り替え
4. 本番環境での動作確認
5. 本番環境動作確認完了報告を国土交通省へ提出

---

## 5. データモデル設計

### 5.1 FlightPlan（飛行計画）

```dart
class FlightPlan {
  final String? flightPlanId;        // 飛行計画ID（新規時はnull）
  final String name;                  // 飛行計画名称
  final List<int> flightPurpose;     // 飛行目的コード（複数）
  final List<int> flightAirspace;    // 飛行空域コード（複数）
  final List<int> flightType;        // 飛行方法コード（複数）
  final int assistantsNumber;         // 補助者数
  final String departurePoint;        // 出発地
  final String destinationPoint;      // 目的地
  final DateTime startTime;           // 飛行開始日時
  final int plannedMaxTime;           // 航続可能時間（分）
  final int plannedFlightTime;        // 所要時間（分）
  final int flightSpeed;              // 飛行速度（km/h）
  final int flightAltitude;           // 飛行高度（m/AGL）
  final FlyRoute flyRoute;            // 飛行経路
  final String riskMitigationOnsiteControl;  // 立入管理措置
  final String exceptionalConditionsMooring; // 係留飛行
  final InsuranceInfo? insuranceInfo; // 保険情報
  final ReporterInfo reporter;        // 通報者情報
  final List<PilotInfo> pilotInfo;   // 操縦者情報
  final List<AircraftInfo> aircraftInfo; // 機体情報
  final PermitInfo? permitInfo;       // 許可・承認情報
}
```

### 5.2 FlyRoute（飛行経路）

```dart
class FlyRoute {
  final String type;       // "Circle" or "Polygon"
  final List<double>? center;  // Circle時: [経度, 緯度]
  final double? radius;        // Circle時: 半径（m）
  final List<List<double>>? coordinates;  // Polygon時: [[経度,緯度]...]

  /// GeoJSON形式の文字列に変換（API送信用）
  String toGeoJson() { ... }
}
```

### 5.3 機体種類コード対応

| コード | 種別 | アプリの「機体種別」 |
|-------|------|-----------------|
| 1 | 飛行機 | 固定翼 |
| 2 | 回転翼航空機（ヘリコプター） | - |
| 3 | 回転翼航空機（マルチローター） | 回転翼 |
| 4 | 回転翼航空機（その他） | - |
| 5 | 滑空機 | - |
| 6 | 飛行船 | - |

---

## 6. セキュリティ設計

### 6.1 機密情報の管理

| 情報 | 保管場所 | 備考 |
|------|---------|------|
| client_id | GAS ScriptProperties | フロントに公開しない |
| client_secret | GAS ScriptProperties | 絶対にフロントに公開しない |
| access_token | GAS ScriptProperties | APIリクエスト時のみGAS内で使用 |
| refresh_token | GAS ScriptProperties | トークン更新時のみGAS内で使用 |
| state パラメータ | GAS CacheService | CSRF対策、認証時に生成・照合 |

### 6.2 通信の安全性

- DIPS API はすべて HTTPS 通信
- GAS Proxy もデフォルトで HTTPS
- Flutter → GAS 間も HTTPS（GAS Web App の URL）

### 6.3 注意事項

- 本番環境で性能負荷試験や異常系試験は禁止
- DIPS アカウントのパスワードはアプリ内に保存しない（ブラウザの認証画面で直接入力）
- redirect_uri は GAS の Web App URL を使用

---

## 7. エラーハンドリング

### 7.1 認証エラー

| エラー | HTTP | 原因 | 対処 |
|--------|------|------|------|
| unauthorized_client | 400 | client_id/secret が不正 | 設定を確認 |
| invalid_request | 400 | grant_type が不正 | リクエスト形式を確認 |
| invalid_grant | 400 | 認可コード期限切れ・無効 | 再度ログインを促す |
| invalid_token | 401 | アクセストークン期限切れ | refresh_token で更新 |

### 7.2 API エラー

| HTTP | 意味 | 対処 |
|------|------|------|
| 400 | パラメータ不正 | エラーメッセージを表示し入力修正を促す |
| 500 | DIPS システムエラー | リトライ or 時間をおいて再試行を案内 |

### 7.3 Flutter 側の表示

- 認証切れ: 「DIPS との接続が切れました。再ログインしてください」ダイアログ
- パラメータエラー: 該当フィールドをハイライトし、修正を促す
- システムエラー: 「DIPS システムに一時的な問題が発生しています」スナックバー

---

## 8. 画面遷移図

```
ホーム画面
  │
  ├── 設定 → DIPS連携設定
  │            ├── 「DIPSにログイン」ボタン → DIPS認証画面（ブラウザ）
  │            ├── 接続状態表示（未接続/接続中/接続済み）
  │            └── 環境切替（検証/本番）※開発者向け
  │
  ├── 機体管理 → DIPS機体一覧
  │              ├── DIPS登録済み機体の表示（機体情報一覧取得API）
  │              ├── アプリ機体マスタとの同期状態表示
  │              └── 未登録機体の追加提案
  │
  ├── 許可・承認 → 許可・承認一覧
  │                ├── 申請状態一覧（申請中/承認済/差戻し）
  │                ├── 「＋新規申請」ボタン → 許可・承認申請フォーム
  │                ├── 許可期間の残日数アラート
  │                └── 承認済み許可の詳細表示
  │
  ├── 飛行予定 → 飛行予定一覧
  │              ├── 「＋新規通報」ボタン → 飛行計画通報フォーム（7ステップ）
  │              │                          └── 送信完了 → 結果表示
  │              ├── 既存飛行計画の編集 → 通報フォーム（flightPlanId付き）
  │              └── 「周辺の飛行計画」ボタン → 飛行計画検索画面
  │                                            └── 地図表示 + リスト
  │
  └── 飛行記録 → 飛行記録詳細
                  └── 「DIPSに通報」ボタン → 通報フォーム（データ自動入力）
```

---

## 9. 開発スケジュール（目安）

| 週 | 作業内容 |
|----|--------|
| 第1週 | Phase A: DIPS API 利用申請書の提出 |
| 第2-3週 | Phase B: GAS Proxy 実装（認証フロー + API中継） |
| 第3-4週 | Phase C: Flutter DIPS連携画面・データモデル |
| 第5-6週 | Phase D: 飛行計画通報フォーム（7ステップウィザード） |
| 第7週 | Phase E: 飛行禁止エリア地図表示 |
| 第8週 | Phase F: 検証環境テスト＆本番移行 |

※ Phase A の API 利用申請から client_id 発行まで数週間かかる可能性あり。申請は最優先で進める。

---

## 10. 参考情報

### 10.1 都道府県コード（岩手県周辺）

| コード | 都道府県 |
|-------|---------|
| 01 | 北海道 |
| 02 | 青森県 |
| 03 | 岩手県 |
| 04 | 宮城県 |
| 05 | 秋田県 |
| 06 | 山形県 |

### 10.2 国コード

日本の国コードは **001** を使用する。

### 10.3 重要な制約事項

- startTime〜finishTime の範囲は24時間以内
- plannedMaxTime / plannedFlightTime は5分単位（5〜1440分）
- flightSpeed は 1〜999 km/h
- flightAltitude は 1〜999 m（AGL: 地上からの高度）
- Polygon の場合、3点以上の構成点が必要（終点は始点と同じ座標をサーバー側で生成）
- flyRoute は GeoJSON 形式の文字列として格納し、内部の `"` はエスケープが必要
- 通報者、操縦者、許可・承認情報のいずれか一つの連絡先フラグが "1" である必要がある
