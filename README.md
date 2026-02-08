<p align="center">
  <img src="icon.png" width="128" height="128" alt="Shinobi Term">
</p>

<h1 align="center">Shinobi Term</h1>

<p align="center">
  <strong>iPhone から Claude Code を使う最短経路</strong><br>
  tmux セッションにワンタップ attach する iOS SSH クライアント
</p>

<p align="center">
  <a href="https://github.com/IE3/shinobi-term/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License: MIT">
  </a>
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-blue.svg" alt="Platform: iOS 17+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9">
</p>

---

## Why

iPhone + Tailscale + ShinobiTerm → Mac の tmux → Claude Code

2025年、Claude Code はターミナルで動く AI 開発ツールになった。SSH で繋がればそのまま使える。でも iOS の既存 SSH アプリだと tmux セッションに手動で attach する手間がある。ShinobiTerm ならワンタップ。

自分用に作った。OSS で無料。

```
┌──────────────┐  Tailscale  ┌──────────────────────────┐
│  iPhone      │ ─────────── │  Mac (自宅 / オフィス)    │
│  ShinobiTerm │     SSH     │  tmux → Claude Code      │
│  ワンタップ   │  ─────────→ │  自然言語で開発           │
└──────────────┘             └──────────────────────────┘
```

### Use Case

> Access Claude Code running in tmux on your home Mac via Tailscale — attach to your session with one tap.

1. 自宅 Mac で `tmux new -s dev` → `claude` を起動しておく
2. 外出先から iPhone で ShinobiTerm を開く
3. tmux attach をタップ → セッション選択 → Claude Code が動いてるターミナルに即接続

<!-- TODO: screenshots here -->
<!-- [スクショ: ホーム画面] → [tmuxセッション一覧] → [Claude Codeターミナル] -->

## Features

- **tmux ワンタップ attach** — セッション一覧から選択、または新規作成してすぐ接続
- **Claude Code companion** — tmux 上の Claude Code と自然言語で開発
- **CJK-first** — 日本語・中国語・韓国語が正しく表示される（Menlo + Hiragino Sans フォールバック）
- **拡張キーボード** — Ctrl, Alt, Esc, Tab, 矢印キー
- **SSH 鍵認証** — Ed25519 鍵ペアをデバイス上で生成、秘密鍵は Keychain に安全に保管
- **セキュア** — パスワード・秘密鍵は iOS Keychain のみに保存、外部送信なし
- **スクロールモード** — tmux copy-mode 連動で出力履歴を閲覧（tmux.conf の設定不要）
- **無料・OSS** — MIT License、広告なし、トラッキングなし

## Design

<p align="center">
  <img src="design/pencil2.png" width="800" alt="Shinobi Term UI Design">
</p>

UI デザインは [Pencil](https://pencil.dev/) で作成。Claude Code MCP 連携によりデザインと実装を高速にイテレーション。

## Getting Started

### Mac 側の準備

#### 1. SSH サーバーを有効化

```
システム設定 → 一般 → 共有 → リモートログイン → ON
```

#### 2. tmux をインストール

```bash
brew install tmux
```

推奨の `~/.tmux.conf`:

```bash
set -g default-terminal "xterm-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
setw -g mode-keys vi
```

#### 3. Claude Code をインストール

```bash
npm install -g @anthropic-ai/claude-code
```

API キーを設定:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# ~/.zshrc にも追記
```

#### 4. tmux セッションを起動

```bash
tmux new -s dev
claude
```

### 外出先からのアクセス（推奨）

[Tailscale](https://tailscale.com/) を Mac と iPhone 両方にインストールすると、同じネットワークにいなくても SSH 接続できます。

```bash
# Mac 側
brew install tailscale
# Tailscale アプリで Sign in → SSH を有効化

# iPhone 側
# App Store から Tailscale をインストール → 同アカウントで Sign in
```

Tailscale の IP（100.x.x.x）を ShinobiTerm の接続先に設定。

### iPhone 側

1. ShinobiTerm を開く
2. `+ add` で接続プロファイルを作成
   - **Host**: Mac の IP（LAN: `192.168.x.x` / Tailscale: `100.x.x.x`）
   - **Port**: `22`
   - **Username / Password**: Mac のログインユーザー（または SSH 鍵認証）
3. **tmux attach** をタップ → セッション選択 → 接続完了

### Tips

- `LANG=en_US.UTF-8` は接続時に自動設定されます
- tmux セッションはデタッチしても維持されるため、接続が切れても作業は失われません
- スクロールモードで出力履歴を閲覧でき、コマンド送信時に自動解除されます

## Tech Stack

| Component   | Library                                                                  |
| ----------- | ------------------------------------------------------------------------ |
| UI          | SwiftUI                                                                  |
| Terminal    | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (xterm-256color) |
| SSH         | [Citadel](https://github.com/orlandos-nl/Citadel) (Pure Swift, SwiftNIO) |
| SSH Keys    | Apple CryptoKit (Ed25519)                                                |
| Data        | SwiftData                                                                |
| Credentials | iOS Keychain                                                             |
| Project     | [XcodeGen](https://github.com/yonaskolb/XcodeGen)                        |

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
│   ├── ConnectionProfile.swift       # 接続プロファイル (SwiftData)
│   └── AppSettings.swift             # アプリ設定
├── Views/
│   ├── ConnectionListView.swift      # 接続一覧
│   ├── ConnectionFormView.swift      # 接続追加・編集
│   ├── TmuxAttachView.swift          # tmux セッション選択・アタッチ
│   ├── TerminalContainerView.swift   # ターミナル + 拡張キーボード
│   ├── ShinobiTerminalView.swift     # SwiftTerm ラッパー
│   ├── ExtraKeysView.swift           # 拡張キーボード
│   ├── SSHKeyManagementView.swift    # SSH 鍵管理
│   └── SettingsView.swift            # 設定
└── Services/
    ├── SSHSession.swift              # Citadel SSH + PTY 管理
    ├── SSHConnectionManager.swift    # セッションライフサイクル
    ├── SSHKeyService.swift           # Ed25519 鍵生成・Keychain 管理
    ├── TmuxService.swift             # tmux ls (executeCommand)
    ├── TipJarService.swift           # StoreKit 2 Tip Jar
    └── KeychainService.swift         # Keychain 読み書き
```

## License

MIT License — Copyright (c) 2025 you tanaka / IE3

See [LICENSE](LICENSE) for details.
