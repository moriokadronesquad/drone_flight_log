# Googleカレンダー連携 セットアップ手順

## 概要
飛行予定をGoogleカレンダーに自動登録するための設定手順です。

---

## 1. Google Cloud Console でプロジェクト作成

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. 「新しいプロジェクト」をクリック
3. プロジェクト名: `drone-flight-log` （任意）

## 2. Google Calendar API を有効化

1. 左メニュー「APIとサービス」→「ライブラリ」
2. 「Google Calendar API」を検索して「有効にする」

## 3. OAuth 同意画面の設定

1. 「APIとサービス」→「OAuth 同意画面」
2. ユーザータイプ: 「外部」を選択
3. アプリ名: `ドローン飛行日誌`
4. スコープに `https://www.googleapis.com/auth/calendar.events` を追加

## 4. OAuth クライアントIDの作成

### Android 用
1. 「認証情報を作成」→「OAuth クライアント ID」
2. アプリケーションの種類: 「Android」
3. パッケージ名: `com.dronepeak.drone_flight_log`
4. SHA-1 フィンガープリント:
   ```
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey
   ```

### iOS 用
1. アプリケーションの種類: 「iOS」
2. バンドルID: `com.dronepeak.droneFlightLog`

### Web 用
1. アプリケーションの種類: 「ウェブアプリケーション」
2. 承認済みのJavaScriptオリジン: `http://localhost:8080`
3. 作成されたクライアントIDを `web/index.html` に追加:
   ```html
   <meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
   ```

## 5. Android 固有の設定

`android/app/build.gradle` の `minSdkVersion` を21以上に設定:
```gradle
defaultConfig {
    minSdkVersion 21
}
```

## 6. iOS 固有の設定

`ios/Runner/Info.plist` に以下を追加:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

## 7. 動作確認

1. アプリを起動
2. ホーム画面の「飛行予定」をタップ
3. 新規予定を登録（「Googleカレンダーに追加」をON）
4. Googleアカウントの認証画面が表示される
5. 認証完了後、Googleカレンダーにイベントが追加される

---

## トラブルシューティング

- **サインインできない**: OAuth同意画面のテストユーザーにGmailアドレスを追加
- **CORS エラー（Web版）**: 承認済みのJavaScriptオリジンを確認
- **scope エラー**: Calendar APIが有効化されているか確認
