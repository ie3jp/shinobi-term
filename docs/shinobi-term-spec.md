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
| Terminal Emulation | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | xterm-compatible terminal emulator with CJK support |
| SSH Connection | [NMSSH](https://github.com/NMSSH/NMSSH) or [Citadel](https://github.com/orlandos-nl/Citadel) (SSH2 via Swift NIO) | SSH2 protocol implementation |
| Font Rendering | System fonts + custom font loading | CJK fallback chain |
| Data Persistence | SwiftData or UserDefaults | Connection profiles, settings |
| Keychain | iOS Keychain Services | SSH key and password storage |
| UI Design Tool | [Pencil](https://www.pencil.dev/) | UI/UXデザイン（Claude Code MCP連携済み） |

### Alternative SSH Libraries

- **NMSSH**: Mature, wraps libssh2, Obj-C but usable from Swift. Well-documented.
- **Citadel**: Pure Swift, built on SwiftNIO. Modern but less battle-tested.
- **SwiftSH**: Another libssh2 wrapper, simpler API.

**Recommendation**: Start with NMSSH for stability, consider migrating to Citadel later for a pure-Swift stack.

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

1. User selects a connection profile → `ConnectionManager` establishes SSH session
2. SSH session opens a PTY (pseudo-terminal) channel
3. PTY stdout → `SwiftTerm` processes escape sequences and renders to `TerminalView`
4. User keyboard input → `SwiftTerm` → PTY stdin → remote shell
5. `SwiftTerm` handles CJK character width (wcwidth) for correct cursor positioning

### tmux Attach Flow

```
User taps "tmux Attach"
  → セッション名入力（or tmux ls から選択）
  → SSH接続確立（未接続の場合）
  → PTY channel で `tmux a -t <session_name>` を実行
  → Claude Code のターミナル UI がそのまま表示される
  → 自然言語で Claude Code と対話開始
```

---

## Feature Specification

### MVP (v1.0)

#### Connection Management

- [ ] Add / edit / delete SSH connection profiles
- [ ] Fields: name, hostname, port (default 22), username, auth method
- [ ] Authentication: password, SSH key (Ed25519, RSA), key + passphrase
- [ ] Import SSH keys from Files app
- [ ] Generate SSH key pair on device
- [ ] Store credentials in iOS Keychain
- [ ] Quick connect: manual hostname:port input

#### tmux Attach（Claude Code 連携）

- [ ] 「tmux Attach」ボタンをメイン UI に配置
- [ ] タップ → セッション名の入力ダイアログ表示
- [ ] `tmux a -t <session_name>` を SSH 経由で実行してアタッチ
- [ ] 直近のセッション名を履歴として保存・サジェスト
- [ ] `tmux ls` の結果からセッション一覧を取得し選択可能に
- [ ] アクティブなセッションがない場合のエラーハンドリング

#### Terminal

- [ ] xterm-256color terminal emulation via SwiftTerm
- [ ] Correct CJK character rendering (double-width characters)
- [ ] Font configuration with CJK fallback chain
- [ ] Configurable font size (pinch to zoom)
- [ ] Color scheme selection (dark / light / custom)
- [ ] Copy & paste support
- [ ] Scrollback buffer (configurable size, default 10,000 lines)

#### Input

- [ ] Standard iOS keyboard input
- [ ] Extra key row: Ctrl, Alt, Esc, Tab, arrow keys, pipe, tilde, etc.
- [ ] Hardware keyboard support (Bluetooth / Smart Keyboard)
- [ ] Ctrl+C, Ctrl+D, Ctrl+Z key combinations

#### Session Management

- [ ] Multiple simultaneous sessions (tab-based)
- [ ] Session reconnection on network change
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
├── ShinobiTermApp.swift              # App entry point
├── Package.swift                     # SPM dependencies
│
├── Models/
│   ├── ConnectionProfile.swift       # SSH connection data model
│   ├── AppSettings.swift             # Global settings model
│   └── SSHKey.swift                  # SSH key model
│
├── Views/
│   ├── ConnectionListView.swift      # Home screen - list of connections
│   ├── ConnectionFormView.swift      # Add/edit connection
│   ├── TerminalContainerView.swift   # Terminal + extra keys wrapper
│   ├── TerminalView.swift            # SwiftTerm integration
│   ├── ExtraKeysView.swift           # Custom keyboard row
│   ├── SettingsView.swift            # App settings
│   ├── FontPickerView.swift          # Font selection with CJK preview
│   └── KeyManagementView.swift       # SSH key management
│
├── Services/
│   ├── SSHConnectionManager.swift    # SSH session lifecycle
│   ├── KeychainService.swift         # Keychain read/write
│   ├── SSHKeyGenerator.swift         # Key pair generation
│   └── FontManager.swift             # Font fallback chain setup
│
├── Helpers/
│   ├── CJKWidthHelper.swift          # Wide character utilities
│   └── ColorScheme.swift             # Terminal color themes
│
├── Resources/
│   └── DefaultSchemes/               # Built-in color schemes (JSON)
│
└── Tests/
    ├── CJKRenderingTests.swift       # CJK width and display tests
    └── SSHConnectionTests.swift      # Connection logic tests
```

---

## Dependencies (Package.swift)

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShinobiTerm",
    platforms: [.iOS(.v17)],
    dependencies: [
        // Terminal emulation
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0"),
        // SSH connection (choose one)
        .package(url: "https://github.com/NMSSH/NMSSH.git", from: "2.3.0"),
        // Alternative: Citadel (pure Swift SSH)
        // .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "ShinobiTerm",
            dependencies: ["SwiftTerm", "NMSSH"]
        ),
    ]
)
```

---

## Build & Distribution

### Requirements

- Xcode 15+
- iOS 17.0+ deployment target
- Swift 5.9+

### Development Setup

```bash
git clone https://github.com/yourname/ShinobiTerm.git
cd ShinobiTerm
open ShinobiTerm.xcodeproj
# or
xcodebuild -scheme ShinobiTerm -destination 'platform=iOS Simulator'
```

### Distribution

- **TestFlight**: For beta testing
- **App Store**: Free, no IAP
- **License**: MIT
- **GitHub Releases**: Source code + IPA (sideload via AltStore)

---

## Implementation Notes

### SwiftTerm Integration

SwiftTerm provides `TerminalView` (UIKit) which can be wrapped in SwiftUI via `UIViewRepresentable`:

```swift
struct TerminalViewWrapper: UIViewRepresentable {
    let terminalView: TerminalView

    func makeUIView(context: Context) -> TerminalView {
        // Configure font with CJK fallback
        let font = FontManager.terminalFont(
            name: settings.fontName,
            size: settings.fontSize
        )
        terminalView.font = font
        return terminalView
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {}
}
```

### SSH → SwiftTerm Bridge

```swift
class SSHTerminalDelegate: TerminalViewDelegate {
    var sshChannel: NMSSHChannel?

    // Terminal → SSH (user input)
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        let bytes = Array(data)
        sshChannel?.write(Data(bytes))
    }

    // SSH → Terminal (remote output)
    func onDataReceived(data: Data) {
        let bytes = [UInt8](data)
        terminalView.feed(byteArray: bytes)
    }
}
```

### Keychain Storage

```swift
class KeychainService {
    static func save(password: String, for profile: ConnectionProfile) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: profile.id.uuidString,
            kSecValueData as String: password.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
}
```

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
- [NMSSH GitHub](https://github.com/NMSSH/NMSSH)
- [Citadel SSH GitHub](https://github.com/orlandos-nl/Citadel)
- [Unicode East Asian Width](https://www.unicode.org/reports/tr11/)
- [xterm control sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
- [iOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
