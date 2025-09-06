# Apple Vision Pro 映像受信アプリ

## 概要
このディレクトリには、iPhoneから送信される顔検出+オーバーレイ画像付き映像を受信・表示するApple Vision Pro専用のコードが含まれています。

## ファイル構成

### [`VisionProMultipeerService.swift`](VisionProMultipeerService.swift:1)
- Apple Vision Pro専用のMultipeer Connectivityサービス
- iPhoneからの映像データ受信を担当
- 自動接続とエラーハンドリング
- Vision Pro最適化された接続管理

### [`VisionProReceiverView.swift`](VisionProReceiverView.swift:1)
- 受信映像表示用のSwiftUIビュー
- 接続状態管理UI
- リアルタイム映像表示
- 複数iPhone対応

## 使用方法

### 1. プロジェクトセットアップ
```swift
// App.swiftまたはメインビューで
import SwiftUI

@main
struct VisionProApp: App {
    var body: some Scene {
        WindowGroup {
            VisionProReceiverView()
        }
    }
}
```

### 2. 実行手順
1. Apple Vision ProでアプリをビルドAndroid実行
2. 「待機開始」ボタンをタップ
3. iPhoneアプリで「待機」→「配信」を実行
4. 自動的に接続され、映像が表示される

## 技術仕様

### 受信機能
- **映像フォーマット**: JPEG
- **フレームレート**: 最大30FPS
- **接続方式**: Multipeer Connectivity
- **暗号化**: 必須

### UI機能
- リアルタイム接続状態表示
- 受信映像のフルスクリーン表示
- 接続パネルの表示/非表示切り替え
- 複数デバイス接続対応

## カスタマイズ

### サービス名の変更
```swift
// VisionProMultipeerService.swift内
private let serviceType = "your-custom-service" // カスタム名に変更
```

### 表示設定の調整
```swift
// VisionProReceiverView.swift内
Image(uiImage: image)
    .resizable()
    .scaledToFit() // .scaledToFill()に変更可能
    .ignoresSafeArea()
```

## 注意事項

### ネットワーク要件
- iPhoneとVision Proが同じWiFiネットワークに接続されている必要があります
- またはBluetooth経由での直接接続

### パフォーマンス
- 受信映像の品質はiPhone側の設定に依存
- ネットワーク状況により遅延が発生する可能性があります

### プライバシー
- ローカルネットワーク内でのみ動作
- 外部サーバーを経由しません

## トラブルシューティング

### 接続できない場合
1. 両デバイスが同じネットワークに接続されているか確認
2. アプリを再起動
3. WiFi接続を一度切断して再接続

### 映像が表示されない場合
1. iPhone側で「配信」ボタンが押されているか確認
2. ネットワーク速度を確認
3. Vision Pro側で「待機開始」が有効か確認

### パフォーマンスが悪い場合
1. 他のネットワーク使用アプリを終了
2. iPhone側のJPEG圧縮率を調整
3. フレームレートを下げる
