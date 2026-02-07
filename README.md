<p align="center">
  <img src="icon.png" width="128" height="128" alt="Shinobi Term">
</p>

<h1 align="center">Shinobi Term</h1>

<p align="center">
  CJK 文字を正しく表示する iOS SSH ターミナル<br>
  iPhone/iPad から tmux + Claude Code へ即座にアタッチ
</p>

---

## Overview

**Shinobi Term** は、CJK（日本語・中国語・韓国語）文字の正確なレンダリングに特化した iOS SSH ターミナルクライアントです。

既存の iOS SSH クライアント（Termius, Moshi 等）では CJK 文字が正しく表示されません。Shinobi Term はこの問題を解決し、Apple Silicon Mac 上の tmux セッションで動く Claude Code と自然言語で対話しながら開発を進めるために作られました。

```
┌──────────────┐     SSH      ┌──────────────────────────┐
│  iPhone/iPad │ ──────────── │  Apple Silicon Mac        │
│  Shinobi Term│              │  tmux → Claude Code      │
│              │  tmux attach │  自然言語で開発指示       │
└──────────────┘              └──────────────────────────┘
```

## Features

- **CJK-first** — 日本語・中国語・韓国語が正しく表示される（Menlo + Hiragino Sans フォールバック）
- **tmux 即アタッチ** — セッション一覧から選択、または新規作成してすぐ接続
- **Claude Code companion** — tmux 上の Claude Code と自然言語で開発
- **拡張キーボード** — Ctrl, Alt, Esc, Tab, 矢印キー等のエクストラキー
- **セキュア** — パスワードは iOS Keychain に保存
- **再接続** — 切断後も再アタッチ可能

## Design

<p align="center">
  <img src="design/pencil.png" width="800" alt="Shinobi Term UI Design">
</p>

UI デザインは [Pencil](https://pencil.dev/) で作成。Claude Code MCP 連携によりデザインと実装を高速にイテレーション。

## Tech Stack

| Component | Library |
|-----------|---------|
| UI | SwiftUI |
| Terminal | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (xterm-256color) |
| SSH | [Citadel](https://github.com/orlandos-nl/Citadel) (Pure Swift, SwiftNIO) |
| Data | SwiftData |
| Credentials | iOS Keychain |
| Project | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |

## Build

```bash
# Requirements: Xcode 15+, XcodeGen
brew install xcodegen

cd ShinobiTerm
xcodegen generate
xcodebuild -scheme ShinobiTerm -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Architecture

```
ShinobiTerm/ShinobiTerm/
├── Models/
│   └── ConnectionProfile.swift       # 接続プロファイル (SwiftData)
├── Views/
│   ├── ConnectionListView.swift      # 接続一覧
│   ├── ConnectionFormView.swift      # 接続追加・編集
│   ├── TmuxAttachView.swift          # tmux セッション選択・アタッチ
│   ├── TerminalContainerView.swift   # ターミナル + 拡張キーボード
│   ├── ShinobiTerminalView.swift     # SwiftTerm ラッパー
│   ├── ExtraKeysView.swift           # 拡張キーボード
│   └── SettingsView.swift            # 設定・フォント選択
└── Services/
    ├── SSHSession.swift              # Citadel SSH + PTY 管理
    ├── SSHConnectionManager.swift    # セッションライフサイクル
    ├── TmuxService.swift             # tmux ls (executeCommand)
    └── KeychainService.swift         # Keychain 読み書き
```

## License

MIT
