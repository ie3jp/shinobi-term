# Lessons

プロジェクト固有の学び・失敗知識を蓄積。
具体的な行動ルールとして記述する。

## ビルド・デプロイ
- 「実機ビルド」と言われたら、ビルド → インストール → 起動まで自律的に完了する。途中で止まって聞かない
- 正しい手順: xcodebuild → xcrun devicectl device install app → 必要なら xcrun devicectl device process launch
- 一般原則: 「〇〇して」と言われたら、目的達成まで自律的に完了する
