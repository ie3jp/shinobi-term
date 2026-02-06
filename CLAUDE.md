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

## 規約

- 共有学習ファイル参照: /Users/you/Library/CloudStorage/Dropbox/_share/learned/
- コーディングスタイル: rules/coding-style.md に従う
- コミットメッセージ: Conventional Commits (feat:, fix:, design:, chore:)
