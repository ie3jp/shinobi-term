import SwiftUI

struct ExtraKeysView: View {
    var onKey: (ExtraKey) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ExtraKey.allKeys, id: \.label) { key in
                Button {
                    onKey(key)
                } label: {
                    Text(key.label)
                        .font(.system(size: key.fontSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color(white: 0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(white: 0.08))
    }
}

enum ExtraKey {
    case esc, ctrl, alt, tab, tilde, pipe
    case arrowUp, arrowDown, arrowLeft, arrowRight

    var label: String {
        switch self {
        case .esc: return "Esc"
        case .ctrl: return "Ctrl"
        case .alt: return "Alt"
        case .tab: return "Tab"
        case .tilde: return "~"
        case .pipe: return "|"
        case .arrowUp: return "\u{2191}"
        case .arrowDown: return "\u{2193}"
        case .arrowLeft: return "\u{2190}"
        case .arrowRight: return "\u{2192}"
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .tilde, .pipe: return 15
        case .arrowUp, .arrowDown, .arrowLeft, .arrowRight: return 14
        default: return 13
        }
    }

    /// ANSI escape sequence for this key
    var sequence: Data {
        switch self {
        case .esc: return Data([0x1B])
        case .tab: return Data([0x09])
        case .tilde: return Data("~".utf8)
        case .pipe: return Data("|".utf8)
        case .arrowUp: return Data([0x1B, 0x5B, 0x41])
        case .arrowDown: return Data([0x1B, 0x5B, 0x42])
        case .arrowRight: return Data([0x1B, 0x5B, 0x43])
        case .arrowLeft: return Data([0x1B, 0x5B, 0x44])
        case .ctrl, .alt: return Data()  // Modifier keys handled separately
        }
    }

    static let allKeys: [ExtraKey] = [
        .esc, .ctrl, .alt, .tab, .tilde, .pipe,
        .arrowUp, .arrowDown, .arrowLeft, .arrowRight,
    ]
}
