# Shinobi Term — iOS SSH Terminal with CJK Support

## Project Overview

**Shinobi Term** is a free, open-source iOS SSH terminal client focused on proper CJK (Chinese, Japanese, Korean) character rendering. Existing iOS SSH clients (Moshi, Termius, etc.) fail to display CJK characters correctly due to missing font fallback and incorrect wide-character width calculation. This app solves that problem.

### Primary Use Case

iPhone/iPad から Apple Silicon Mac に SSH 接続し、Mac 上の **tmux セッションで起動している Claude Code** と自然言語で対話しながら開発を進める。

```
┌──────────────┐     SSH      ┌──────────────────────────┐
│  iPhone/iPad │ ──────────── │  Apple Silicon Mac        │
│  Shinobi Term│              │  tmux → Claude Code      │
│              │  tmux attach │  自然言語で開発指示       │
└──────────────┘              └──────────────────────────┘
```

### Target Users

- Apple Silicon Mac で Claude Code を使い、外出先や別室から iPhone/iPad で開発を継続したいユーザー
- Developers and sysadmins who need SSH access from iPhone/iPad
- Users in CJK regions who need proper display of their native language in terminal output
- Tailscale / WireGuard users who SSH into local machines from mobile

### Design Philosophy

- **CJK-first**: Japanese, Chinese, Korean text must render correctly out of the box
- **Claude Code companion**: tmux セッションへの即座のアタッチで、自然言語開発をシームレスに
- **Minimal & functional**: No bloat, no subscription, no account required
- **Open source**: MIT License, hosted on GitHub
- **Free forever**: No IAP, no ads

---

## Tech Stack

| Component | Library / Tool | Purpose |
|-----------|---------------|---------|
| UI Framework | SwiftUI | App UI, settings, connection management |
| Terminal Emulation | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (main branch) | xterm-compatible terminal emulator with CJK support |
| SSH Connection | [Citadel](https://github.com/orlandos-nl/Citadel) (Pure Swift, SwiftNIO) | SSH2 protocol implementation |
| Font Rendering | System fonts (Menlo + Hiragino Sans fallback) | CJK fallback chain |
| Data Persistence | SwiftData | Connection profiles, settings |
| Keychain | iOS Keychain Services | SSH key and password storage |
| Project Generator | [XcodeGen](https://github.com/yonaskolb/XcodeGen) | project.yml → .xcodeproj |
| UI Design Tool | [Pencil](https://www.pencil.dev/) | UI/UXデザイン（Claude Code MCP連携済み） |

### SSH Library: Citadel

Pure Swift implementation built on SwiftNIO を採用。主な利点:
- `SSHClient.executeCommand()` で PTY を介さないクリーンなコマンド実行（tmux ls 等に使用）
- `withPTY()` でインタラクティブターミナルセッション
- SwiftNIO ベースの非同期 I/O

---

## Core Architecture

```
┌─────────────────────────────────────────────┐
│                   SwiftUI                    │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │Connection│  │ Terminal  │  │ Settings  │  │
│  │  List    │  │  View     │  │   View    │  │
│  └────┬─────┘  └────┬─────┘  └───────────┘  │
│       │              │                        │
├───────┼──────────────┼────────────────────────┤
│       │              │                        │
│  ┌────▼─────┐  ┌────▼──────────────────────┐ │
│  │Connection│  │   SwiftTerm               │ │
│  │ Manager  │  │  (TerminalView)           │ │
│  │          │  │  - xterm emulation        │ │
│  │  - SSH   │  │  - CJK width calculation  │ │
│  │  - Auth  │  │  - Font fallback chain    │ │
│  │  - PTY   │  │  - Input handling         │ │
│  └────┬─────┘  └────▲──────────────────────┘ │
│       │              │                        │
│       └──────────────┘                        │
│         SSH data stream (stdin/stdout)        │
└─────────────────────────────────────────────┘
```

### Data Flow

1. User selects a connection profile → `SSHConnectionManager` creates/retrieves `SSHSession`
2. `SSHSession.connect()` → Citadel `SSHClient.connect()` で SSH 接続確立
3. `startPTYSession()` → `client.withPTY()` で PTY チャネル開設
4. PTY stdout → `AsyncStream` → `onDataReceived` callback → SwiftTerm `feed()`
5. User keyboard input → SwiftTerm → `AsyncStream<ByteBuffer>` → PTY stdin → remote shell
6. tmux セッション一覧取得は `SSHClient.executeCommand()` で PTY を介さず直接実行

### tmux Attach Flow

```
User taps "tmux Attach"
  → SSHSession.connect() で接続確立
  → SSHClient.executeCommand("bash -lc 'tmux ls'") でセッション一覧取得
  → ユーザーがセッション選択 or 手動入力
  → TerminalContainerView に initialCommand として tmux コマンドを渡す
  → .task で LANG 設定後、tmux a -t <name> || tmux new -s <name> を送信
  → Claude Code のターミナル UI がそのまま表示される
```

---

## Feature Specification

### MVP (v1.0)

#### Connection Management

- [x] Add / edit / delete SSH connection profiles
- [x] Fields: name, hostname, port (default 22), username, auth method
- [x] Authentication: password
- [ ] Authentication: SSH key (Ed25519, RSA), key + passphrase
- [ ] Import SSH keys from Files app
- [ ] Generate SSH key pair on device
- [x] Store credentials in iOS Keychain (stable UUID-based profileId)
- [ ] Quick connect: manual hostname:port input

#### tmux Attach（Claude Code 連携）

- [x] 「tmux Attach」ボタンをメイン UI に配置
- [x] `tmux ls` の結果からセッション一覧を取得し選択可能に（executeCommand 使用）
- [x] セッション選択 or 手動入力でアタッチ
- [x] `tmux a -t <name> || tmux new -s <name>` で存在しない場合は新規作成
- [x] 直近のセッション名を履歴として保存（lastTmuxSession）
- [x] 切断後の再アタッチ（自動再接続）
- [x] CJK 環境変数の自動設定（LANG=en_US.UTF-8）

#### Terminal

- [x] xterm-256color terminal emulation via SwiftTerm
- [x] Correct CJK character rendering (double-width characters)
- [x] Font configuration with CJK fallback chain (Menlo + Hiragino Sans)
- [ ] Configurable font size (pinch to zoom)
- [ ] Color scheme selection (dark / light / custom)
- [ ] Copy & paste support
- [ ] Scrollback buffer (configurable size, default 10,000 lines)

#### Input

- [x] Standard iOS keyboard input
- [x] Extra key row: Ctrl, Alt, Esc, Tab, arrow keys, pipe, tilde, etc.
- [ ] Hardware keyboard support (Bluetooth / Smart Keyboard)
- [x] Ctrl+key combinations (Ctrl toggle + key → control character)

#### Session Management

- [ ] Multiple simultaneous sessions (tab-based)
- [x] Session reconnection on re-attach
- [ ] Background keepalive (within iOS limits)

### v1.1 Enhancements

- [ ] Mosh protocol support (for unstable networks)
- [ ] SFTP file browser
- [ ] Port forwarding (local / remote)
- [ ] Snippet / command palette
- [ ] URL detection and opening
- [ ] Tailscale integration (auto-discover devices)

### v2.0 Future

- [ ] iPad split-view / multi-window
- [ ] Shortcuts app integration
- [ ] Custom themes (import/export)
- [ ] tmux integration helpers

---

## CJK Rendering — The Core Problem & Solution

### Problem

Most iOS terminal apps use monospace fonts that lack CJK glyphs. Even when glyphs exist, the terminal emulator often fails to calculate the correct display width for CJK characters (which are "wide" / double-width in terminal context).

### Solution

#### 1. Font Fallback Chain

```swift
// Primary: user-selected monospace font for ASCII
// Fallback: system CJK font for wide characters
let fontDescriptor = UIFontDescriptor(fontAttributes: [
    .name: "Menlo-Regular"  // or user-selected font
])

// Add CJK fallback using cascadeList
let cjkFallback = UIFontDescriptor(fontAttributes: [
    .name: "HiraginoSans-W3"  // Japanese
])
let cascadeDescriptor = fontDescriptor.addingAttributes([
    .cascadeList: [cjkFallback]
])
```

**Fallback priority:**
1. User-selected monospace font (Menlo, SF Mono, JetBrains Mono, etc.)
2. Hiragino Sans (Japanese) — built into iOS
3. PingFang SC (Simplified Chinese) — built into iOS
4. PingFang TC (Traditional Chinese) — built into iOS
5. Apple SD Gothic Neo (Korean) — built into iOS

#### 2. Wide Character Width

SwiftTerm already implements `wcwidth()` for determining character display width. Verify and test that:
- CJK Unified Ideographs (U+4E00–U+9FFF) → width 2
- Hiragana (U+3040–U+309F) → width 2
- Katakana (U+30A0–U+30FF) → width 2
- Halfwidth Katakana (U+FF65–U+FF9F) → width 1
- CJK fullwidth forms (U+FF01–U+FF60) → width 2
- Emoji with variation selectors → proper width handling

#### 3. Testing Checklist

```bash
# Run these on the remote server and verify correct display:

# Basic Japanese
echo "こんにちは世界"

# Mixed ASCII and Japanese
echo "Hello こんにちは World"

# Table alignment (columns should align)
printf "%-10s %-10s\n" "Name" "名前"
printf "%-10s %-10s\n" "Alice" "太郎"

# CJK in common CLI tools
ls -la  # with Japanese filenames
git log --oneline  # with Japanese commit messages
```

---

## UI Design

### Design Language

- Clean, minimal dark-mode first design
- Inspired by modern terminal emulators (Warp, Alacritty, Ghostty)
- No skeuomorphism, flat design with subtle depth
- System colors for adaptability

### Screen Flow

```
Launch
  ├── Connection List (Home)
  │     ├── + Add Connection → Connection Form
  │     ├── 🥷 tmux Attach → セッション選択 → Terminal View
  │     ├── Tap connection → Terminal View
  │     └── Settings → Settings View
  │
  ├── tmux Attach Flow
  │     ├── tmux ls でセッション一覧取得
  │     ├── セッション選択 or 手動入力
  │     └── tmux a -t <name> → Terminal View
  │
  ├── Terminal View
  │     ├── Terminal display area (SwiftTerm)
  │     ├── Extra key row (Ctrl, Alt, Esc, Tab, ↑↓←→)
  │     ├── Swipe left/right → switch tabs
  │     └── Top bar: connection name, disconnect button
  │
  └── Settings View
        ├── Appearance
        │     ├── Font (picker with CJK preview)
        │     ├── Font size
        │     └── Color scheme
        ├── Terminal
        │     ├── Scrollback buffer size
        │     └── Bell behavior
        ├── Keys
        │     ├── SSH key management
        │     └── Generate new key pair
        └── About
              ├── Version
              ├── GitHub link
              └── License (MIT)
```

### UI Design Workflow

UI/UXデザインは **[Pencil](https://www.pencil.dev/)** を使用して作成する。

- Pencil は Claude Code と MCP 連携済み（インストール・設定完了）
- `.pen` ファイルでデザインを管理
- Claude Code から Pencil MCP ツールで直接デザインの読み書きが可能
- デザイン → 実装のイテレーションを高速化

### Extra Key Row Layout

```
┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
│ Esc  │ Ctrl │ Alt  │ Tab  │  ↑   │  ~   │  |   │  /   │
├──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┤
│      │      │      │      │ ←↓→  │      │      │      │
└──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
```

- Ctrl and Alt are toggleable (highlight when active)
- Long-press on Ctrl shows Ctrl+key shortcuts
- Arrow keys: tap for single press, hold for repeat
- Swipe up on extra row to show more keys

---

## Project Structure

```
ShinobiTerm/
├── project.yml                       # XcodeGen 設定
├── ShinobiTerm/
│   ├── ShinobiTermApp.swift          # App entry point
│   ├── ContentView.swift             # Tab navigation (connections, settings)
│   │
│   ├── Models/
│   │   └── ConnectionProfile.swift   # SSH connection data model (SwiftData)
│   │
│   ├── Views/
│   │   ├── ConnectionListView.swift      # Home - connection list
│   │   ├── ConnectionFormView.swift      # Add/edit connection
│   │   ├── TmuxAttachView.swift          # tmux session list + attach
│   │   ├── TerminalContainerView.swift   # Terminal + extra keys wrapper
│   │   ├── ShinobiTerminalView.swift     # SwiftTerm UIViewRepresentable
│   │   ├── ExtraKeysView.swift           # Custom keyboard row
│   │   └── SettingsView.swift            # App settings + font picker
│   │
│   ├── Services/
│   │   ├── SSHSession.swift              # Citadel SSH + PTY management
│   │   ├── SSHConnectionManager.swift    # Session lifecycle (per profile)
│   │   ├── TmuxService.swift             # tmux ls via executeCommand
│   │   └── KeychainService.swift         # Keychain read/write
│   │
│   ├── Resources/
│   │   └── Assets.xcassets/              # Color assets (dark theme)
│   │
│   └── Info.plist
│
├── docs/                             # 仕様書
└── design/                           # Pencil デザイン (.pen)
```

---

## Dependencies (via XcodeGen project.yml)

- **SwiftTerm** (main branch) — Terminal emulation with CJK support
- **Citadel** (0.7.0+) — Pure Swift SSH client built on SwiftNIO

---

## Build & Distribution

### Requirements

- Xcode 15+
- iOS 17.0+ deployment target
- Swift 5.9+
- XcodeGen (`brew install xcodegen`)

### Development Setup

```bash
git clone https://github.com/yourname/ShinobiTerm.git
cd ShinobiTerm/ShinobiTerm
xcodegen generate
xcodebuild -scheme ShinobiTerm -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Distribution

- **TestFlight**: For beta testing
- **App Store**: Free, no IAP
- **License**: MIT
- **GitHub Releases**: Source code + IPA (sideload via AltStore)

---

## Implementation Notes

### SwiftTerm Integration (`ShinobiTerminalView`)

SwiftTerm の `TerminalView` (UIKit) を `UIViewRepresentable` でラップ。
`SSHSession.onDataReceived` コールバックで受信データを `terminalView.feed()` に転送。

### SSH Session (`SSHSession`)

Citadel の `SSHClient` を使用した SSH セッション管理:
- `connect()` → `SSHClient.connect()` で認証・接続
- `startPTYSession()` → `client.withPTY()` で PTY 開設、`AsyncStream<ByteBuffer>` で stdin/stdout を非同期処理
- `send()` → stdin の `AsyncStream.Continuation` に `ByteBuffer` を yield
- `resize()` → `TTYStdinWriter.changeSize()` でターミナルサイズ変更
- `disconnect()` → race condition を防ぐため `client = nil` を同期的に実行

### tmux セッション一覧 (`TmuxService`)

`SSHClient.executeCommand("bash -lc 'tmux ls' 2>/dev/null || true")` でクリーンな出力を取得。
PTY を使わないため ANSI エスケープやプロンプトの汚染がない。
`bash -lc` でログインシェルを使用し、Homebrew の tmux を PATH に含める。

### Keychain Key の安定性

`ConnectionProfile.profileId` に `UUID().uuidString` を使用。
Swift の `hashValue` はプロセスごとにランダム化されるため、Keychain キーには不適。
`@Attribute(.unique)` で SwiftData の一意性を保証。

---

## Testing Strategy

### CJK Rendering Tests (Critical)

1. Single Japanese line renders correctly
2. Mixed ASCII + CJK line maintains alignment
3. CJK characters occupy 2 cells in terminal grid
4. Cursor position is correct after CJK characters
5. Line wrapping works correctly with CJK at line boundary
6. Halfwidth katakana occupies 1 cell
7. vim / nano editor cursor navigation with CJK content
8. `htop` / `top` display with CJK process names
9. `git log` with CJK commit messages

### SSH Tests

1. Password authentication
2. Key-based authentication (RSA, Ed25519)
3. Key + passphrase authentication
4. Connection timeout handling
5. Network interruption and reconnection
6. Multiple simultaneous sessions
7. PTY resize on device rotation

### tmux Attach Tests

1. `tmux ls` でセッション一覧が正しく取得・表示される
2. 存在するセッションへの `tmux a -t` が成功する
3. 存在しないセッション名でのエラーハンドリング
4. Claude Code 起動中の tmux セッションでの日本語入出力
5. tmux 内での Claude Code のターミナル UI が正しくレンダリングされる
6. セッション名の履歴保存と復元

### Compatibility Tests

- Apple Silicon Mac (macOS 14+) — Primary target
- Tailscale SSH
- Standard OpenSSH server
- Dropbear SSH
- AWS EC2
- Raspberry Pi

---

## Naming & Branding

- **App Name**: Shinobi Term (忍びターム)
- **Tagline**: "SSH terminal that speaks your language"
- **Icon concept**: Minimal terminal cursor icon with a subtle Japanese design element
- **Color accent**: Indigo (#5856D6) matching iOS system accent

---

## References

- [SwiftTerm GitHub](https://github.com/migueldeicaza/SwiftTerm)
- [Citadel SSH GitHub](https://github.com/orlandos-nl/Citadel)
- [Unicode East Asian Width](https://www.unicode.org/reports/tr11/)
- [xterm control sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
- [iOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
