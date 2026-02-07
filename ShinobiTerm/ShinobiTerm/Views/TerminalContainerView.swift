import SwiftUI

struct TerminalContainerView: View {
    let session: SSHSession
    let profileName: String
    var tmuxSession: String?
    var initialCommand: String?
    var fontName: String = "Menlo"
    var fontSize: CGFloat = 14
    @Environment(\.dismiss) private var dismiss
    @State private var isCtrlActive = false
    @State private var isAltActive = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            terminalBar

            // Terminal
            ShinobiTerminalView(
                session: session,
                fontName: fontName,
                fontSize: fontSize
            )

            // Extra Keys
            ExtraKeysView(
                onKey: { handleExtraKey($0) },
                isCtrlActive: isCtrlActive,
                isAltActive: isAltActive
            )
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .task {
            // Wait for ShinobiTerminalView to set up onDataReceived
            try? await Task.sleep(for: .milliseconds(300))
            // Set UTF-8 locale for CJK support
            session.send("export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8\n")
            if let cmd = initialCommand {
                try? await Task.sleep(for: .milliseconds(100))
                session.send(cmd)
            }
        }
    }

    private var terminalBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(session.state == .connected ? Color("greenPrimary") : Color("redError"))
                    .frame(width: 8, height: 8)
                Text(profileName)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color("textPrimary"))
                if let tmux = tmuxSession {
                    Text("// tmux:\(tmux)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color("textMuted"))
                }
            }

            Spacer()

            Button {
                session.disconnect()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("textTertiary"))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color("bgSurface"))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color("borderPrimary"))
                .frame(height: 1)
        }
    }

    private func handleExtraKey(_ key: ExtraKey) {
        switch key {
        case .ctrl:
            isCtrlActive.toggle()
        case .alt:
            isAltActive.toggle()
        default:
            if isCtrlActive {
                isCtrlActive = false
                // Send Ctrl+key by converting to control character
                if let char = key.label.lowercased().first,
                   let ascii = char.asciiValue {
                    let ctrlChar = ascii & 0x1F
                    session.send(Data([ctrlChar]))
                } else {
                    session.send(key.sequence)
                }
            } else {
                session.send(key.sequence)
            }
        }
    }
}
