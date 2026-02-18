# Lessons

プロジェクト固有の学び・失敗知識を蓄積。
具体的な行動ルールとして記述する。

## ビルド・デプロイ
- 「実機ビルド」と言われたら、ビルド → インストール → 起動まで自律的に完了する。途中で止まって聞かない
- 正しい手順: xcodebuild → xcrun devicectl device install app → 必要なら xcrun devicectl device process launch
- 一般原則: 「〇〇して」と言われたら、目的達成まで自律的に完了する
- Info.plist に `ITSAppUsesNonExemptEncryption = false` を必ず含める。未設定だとビルドアップロード後に暗号化宣言が必要になり、審査提出がブロックされる
- ビルド番号（CURRENT_PROJECT_VERSION）は App Store Connect 上の既存ビルド番号より大きくする。`asc builds list` で最大値を確認してから決める
- リジェクト後の再提出: 既存の UNRESOLVED_ISSUES submission をキャンセル → 新規 submission 作成 → version を items-add → submissions-submit。既存 submission に version が紐づいたままだと新規作成できない
- `asc` CLI で App Store Connect 操作が全て可能。`asc versions`, `asc builds`, `asc submit`, `asc review` 等。認証情報は `~/.asc/config.json`

## StoreKit / IAP
- `Product.products(for:)` が失敗した場合のフォールバックを必ず実装する。guard で無言 return すると「ボタン無反応」でリジェクトされる
- IAP が WAITING_FOR_REVIEW 状態だと審査環境で商品取得できない。初回リリース時は特に注意（IAP とアプリが同時審査）
- 商品取得失敗時は再取得を試行し、それでもダメならユーザーにエラーメッセージを表示する
- **SwiftUI で同一ビューに `.alert` を2つ付けない**。iPad で片方が表示されない既知バグがある。単一 `.alert` + enum/状態分岐で統合する
- alert だけに頼らず、**インラインエラー表示**もフォールバックとして実装する（alert が表示されない環境対策）
- `.buttonStyle(.plain)` は視覚フィードバックがゼロ。iPad 審査で「No action occurs」と判定される原因になる。カスタム ButtonStyle で press 状態を表示する
- ボタンに `.contentShape(Rectangle())` を付けて、ラベル全体をタップ可能にする（Spacer 部分も含む）
