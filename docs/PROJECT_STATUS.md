# ドローンログ × DIPS 2.0 API連携 プロジェクトサマリー

**最終更新**: 2026年4月10日
**ステータス**: ⏸ 一時停止（API利用申請の受理待ち）

---

## プロジェクト概要

- **アプリ名**: ドローンログ（Flutter Web）
- **運営**: 湊運輸倉庫株式会社（ブランド名: DRONE PEAK）
- **担当者**: 石川 啓（toru-i@dronepeak.jp / 019-681-3499）
- **GitHub**: moriokadronesquad / drone_flight_log
- **公開URL**: https://moriokadronesquad.github.io/drone_flight_log/
- **GAS Web API**: https://script.google.com/macros/s/AKfycbxgoZIbdJ12dv-bkd_ld17VbbDNVACVzxqRiZhOslPl_ACTO6S4P_f9IKFO60ZqSsPQyg/exec
- **スプレッドシート**: https://docs.google.com/spreadsheets/d/1ZV6vx0654hOMFvJB_CUdPqy5AHDSe4wJOHKGufCVtxU/edit
- **Googleアカウント**: minato.morioka@gmail.com
- **Gmailコネクタ**: mods.morioka@gmail.com（下書き作成に使用）

---

## 完了した作業

### 1. DIPS 2.0 API連携 設計書
- **ファイル**: `docs/DIPS2_Design_Document.md`
- 全6つのAPIを網羅（機体情報一覧取得、許可・承認情報取得、許可・承認申請受付、飛行計画情報取得、飛行禁止エリア情報取得、飛行計画通報受付）
- システム構成: Flutter Web → GAS Proxy → DIPS API
- OpenID Connect認証フロー、トークン管理、GAS Proxy設計、Flutter画面構成、データモデル、セキュリティ設計、エラーハンドリング、開発スケジュールを記載

### 2. API利用申請書（Excel）
- **ファイル**: `docs/DIPS2_Application_v4.xlsx`（最新版を使用すること）
- 検証環境新規申請 〇、申請日 2026/4/9（v4で再提出済み）
- 接続システムURL: `https://dronepeak-dips.minato-morioka.jp`
- リダイレクトURL: `https://dronepeak-dips.minato-morioka.jp/auth/callback`
- アクセス元IP: 133.125.37.102
- ※古いバージョン（v1〜v3）は使わないこと

### 3. 申請ガイド
- **ファイル**: `docs/DIPS2_Application_Guide.md`
- 申請の全体フロー（8ステップ）、メール文面、記入ガイド

### 4. 申請メール下書き
- **Gmail**: mods.morioka@gmail.com の下書きに保存済み
- **宛先**: hqt-jcab.mujin@ki.mlit.go.jp
- **件名**: DIPS2.0 API（FPR）利用申請について
- **注意**: 申請書Excel（v3）を手動で添付してから送信すること

---

## 完了した作業（追加: 2026-04-09）

### 5. FastAPI Proxy 実装・デプロイ（`dips_proxy/`）

- **アーキテクチャ変更**: GAS Proxy → さくらVPS (FastAPI) に変更（固定IP要件のため）
- **ファイル**: `dips_proxy/` ディレクトリ
- OpenID Connect Authorization Code Flow + PKCE 実装
- トークン管理（Fernet暗号化ファイルに保管、自動更新）
- DIPS 2.0 API 6エンドポイントの中継ルーター
- CORS、ヘルスチェック、Docker Compose 構成
- **さくらVPS デプロイ完了** (Debian 12, IP: 133.125.37.102)
- **HTTPS化完了** (Caddy + Let's Encrypt、外部から200 OK確認済み)
- ドメイン: `dronepeak-dips.minato-morioka.jp` (ムームーDNS)
- `.env` はダミー値で稼働中（国交省の認証情報待ち）

### 6. 認証コールバック実装・テスト拡充・コード品質改善（2026-04-10）

- **GET /auth/callback 追加**: B案（サーバーサイド完結型）対応。DIPSからのリダイレクトを受信→トークン交換→Flutter Webへリダイレクト
- `config.py` に `frontend_url` 設定追加（環境変数 `FRONTEND_URL` で上書き可能）
- **Pythonテスト追加**: `test_auth_callback_get.py` 7テストケース（合計19件）
- **Flutterテスト追加**: pilot_repository（10件）、validation_service（30+件）、flight_summary_service（9件）
- **コード品質修正**: `dynamic` 型を適切な型に修正（GoRouter, FlightScheduleData, DailyInspectionData, Map<String, dynamic>, Object?）計7箇所
- Git初期化、GitHubリモート設定済み

---

## 次のアクション（申請受理後）

1. 国交省から検証環境用 client_id / client_secret を受領
2. API設定通知書を受領（機体情報一覧取得API等の詳細仕様はここに記載）
3. さくらVPS `.env` に client_id / client_secret を設定 → `docker compose restart`（デプロイ・HTTPS化は完了済み）
4. API設定通知書に基づきリクエスト/レスポンス型を確定・更新
5. Flutter側 DIPS連携画面の実装
6. 検証環境テスト → 完了報告 → 本番環境移行

---

## 技術メモ

- FPRガイドライン PDF: 5-4, 5-5, 5-6 の詳細仕様あり。5-1, 5-2, 5-3 はAPI設定通知書で確認
- ~~GAS Proxyが必要な理由: CORS制限、client_secret保護、トークン管理~~ → FastAPI Proxyに変更
- 構成: Flutter Web (GitHub Pages) → さくらVPS (FastAPI / 固定IP) → DIPS 2.0 API
- GASは既存スプレッドシート連携に引き続き使用、DIPS連携のみVPS
- トークン: access_token 300秒、refresh_token 3600秒、Fernet暗号化ファイルに保管
- さくらVPS: 512MBプラン（月590円）で固定IP取得
- 本番環境OpenID Connect: 検証環境と同じなら「同上」で記載
- 設定通知欄（Client ID等）: 国交省が記入して返送するため空欄でOK
- 別紙１（申請者ID/パスワード）: 国交省からテストアカウントとして発行される
