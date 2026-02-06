import SwiftUI

struct TerminalContainerView: View {
    let session: SSHSession
    let profileName: String
    var fontName: String = "Menlo"
    var fontSize: CGFloat = 14
    @Environment(\.dismiss) private var dismiss
    @State private var isCtrlActive = false
    @State private var isAltActive = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    session.disconnect()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.indigo)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(session.state == .connected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(profileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                // Placeholder for right-side action
                Color.clear.frame(width: 60)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color(white: 0.09))

            // Terminal
            ShinobiTerminalView(
                session: session,
                fontName: fontName,
                fontSize: fontSize
            )

            // Extra Keys
            ExtraKeysView { key in
                handleExtraKey(key)
            }
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
    }

    private func handleExtraKey(_ key: ExtraKey) {
        switch key {
        case .ctrl:
            isCtrlActive.toggle()
        case .alt:
            isAltActive.toggle()
        default:
            if isCtrlActive {
                // Send Ctrl+key: Ctrl modifies the next character
                isCtrlActive = false
                session.send(key.sequence)
            } else {
                session.send(key.sequence)
            }
        }
    }
}
