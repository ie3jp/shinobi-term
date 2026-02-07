# Shinobi Term

iOS SSH ターミナルクライアント。CJK 文字の正確なレンダリングと tmux/Claude Code 連携に特化。

## 技術スタック

- **Platform**: iOS 17.0+, Swift 5.9+
- **UI**: SwiftUI + UIViewRepresentable (SwiftTerm TerminalView)
- **Terminal**: SwiftTerm (main branch)
- **SSH**: Citadel (Pure Swift, SwiftNIO)
- **Data**: SwiftData
- **Credentials**: iOS Keychain
- **Design**: Pencil (.pen files)
- **Project**: XcodeGen (project.yml → .xcodeproj)

## プロジェクト構成

```
ShinobiTerm/
├── project.yml           # XcodeGen 設定
├── ShinobiTerm/          # App ソース
│   ├── Models/
│   ├── Views/
│   ├── Services/
│   └── Resources/
├── docs/                 # 仕様書
└── design/               # Pencil デザイン (.pen)
```

## ビルド

```bash
cd ShinobiTerm
xcodegen generate
xcodebuild -scheme ShinobiTerm -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## 実装済み機能

- SSH 接続管理（接続プロファイルの追加・編集・削除）
- パスワード認証（Keychain 保存、stable UUID ベースのキー）
- ターミナルエミュレーション（SwiftTerm、xterm-256color）
- CJK 文字の正常表示（Menlo + Hiragino Sans フォールバック、LANG 自動設定）
- tmux セッション一覧取得（`executeCommand` による直接実行）
- tmux アタッチ / 新規セッション作成
- 切断後の再接続・再アタッチ
- 拡張キーボード（Ctrl, Alt, Esc, Tab, 矢印キー等）
- 設定画面（フォント選択）

## 既知の技術的注意点

- `persistentModelID.hashValue` は Swift のハッシュランダム化でプロセスごとに変わるため Keychain キーに使用不可 → `profileId: UUID` で解決済み
- tmux セッション一覧は `SSHClient.executeCommand("bash -lc 'tmux ls'")` で取得。PTY 経由だと ANSI エスケープで汚染される
- `disconnect()` 内の `client = nil` は同期的に実行する必要あり（非同期にすると再接続時に race condition）
- TerminalContainerView の `.task` で LANG 設定 → initialCommand の順で送信。SwiftTerm の `onDataReceived` セットアップ待ちに 300ms の遅延

## 規約

- 共有学習ファイル参照: /Users/you/Library/CloudStorage/Dropbox/_share/learned/
- コーディングスタイル: rules/coding-style.md に従う
- コミットメッセージ: Conventional Commits (feat:, fix:, design:, chore:)
