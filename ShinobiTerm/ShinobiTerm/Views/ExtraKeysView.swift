import SwiftUI

struct ExtraKeysView: View {
    var onKey: (ExtraKey) -> Void
    var isCtrlActive: Bool = false
    var isAltActive: Bool = false
    var isReadActive: Bool = false
    var isClaudeActive: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Esc, Ctrl, Alt, Tab, ↑, ~, |, /
            HStack(spacing: 4) {
                ForEach(ExtraKey.topRow, id: \.label) { key in
                    extraKeyButton(key)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color("bgSurface"))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color("borderPrimary"))
                    .frame(height: 1)
            }

            // Row 2: Read, ←, ↓, →, 👾, ⌨
            HStack(spacing: 4) {
                extraKeyButton(.read)
                    .frame(maxWidth: .infinity)
                Spacer()
                ForEach(ExtraKey.bottomRow, id: \.label) { key in
                    extraKeyButton(key)
                }
                Spacer()
                extraKeyButton(.claude)
                extraKeyButton(.keyboard)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
            .background(Color("bgSurface"))
        }
    }

    private func extraKeyButton(_ key: ExtraKey) -> some View {
        let isActive = (key == .ctrl && isCtrlActive)
            || (key == .alt && isAltActive)
            || (key == .read && isReadActive)
            || (key == .claude && isClaudeActive)

        return Button {
            onKey(key)
        } label: {
            Text(key.label)
                .font(.system(size: key.fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(isActive ? Color("greenPrimary") : Color("textPrimary"))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isActive ? Color("greenPrimary").opacity(0.15) : Color("bgElevated"))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

enum ExtraKey: Equatable {
    case esc, ctrl, alt, tab, enter, tilde, pipe, slash
    case arrowUp, arrowDown, arrowLeft, arrowRight
    case read, keyboard, claude

    var label: String {
        switch self {
        case .esc: return "Esc"
        case .ctrl: return "Ctrl"
        case .alt: return "Alt"
        case .tab: return "Tab"
        case .enter: return "\u{23CE}"
        case .tilde: return "~"
        case .pipe: return "|"
        case .slash: return "/"
        case .arrowUp: return "\u{2191}"
        case .arrowDown: return "\u{2193}"
        case .arrowLeft: return "\u{2190}"
        case .arrowRight: return "\u{2192}"
        case .read: return "Read"
        case .keyboard: return "\u{2328}"
        case .claude: return "\u{1F47E}"
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .tilde, .pipe, .slash: return 15
        case .enter: return 16
        case .arrowUp, .arrowDown, .arrowLeft, .arrowRight: return 14
        case .read: return 12
        case .keyboard: return 48
        case .claude: return 20
        default: return 13
        }
    }

    var sequence: Data {
        switch self {
        case .esc: return Data([0x1B])
        case .tab: return Data([0x09])
        case .enter: return Data([0x0D])
        case .tilde: return Data("~".utf8)
        case .pipe: return Data("|".utf8)
        case .slash: return Data("/".utf8)
        case .arrowUp: return Data([0x1B, 0x5B, 0x41])
        case .arrowDown: return Data([0x1B, 0x5B, 0x42])
        case .arrowRight: return Data([0x1B, 0x5B, 0x43])
        case .arrowLeft: return Data([0x1B, 0x5B, 0x44])
        case .ctrl, .alt, .read, .keyboard, .claude: return Data()
        }
    }

    static let topRow: [ExtraKey] = [
        .esc, .ctrl, .alt, .tab, .enter, .arrowUp, .tilde, .pipe, .slash,
    ]

    static let bottomRow: [ExtraKey] = [
        .arrowLeft, .arrowDown, .arrowRight,
    ]
}
