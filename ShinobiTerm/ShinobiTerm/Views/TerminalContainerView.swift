import SwiftUI
import UIKit

struct TerminalContainerView: View {
    let session: SSHSession
    let profileName: String
    var tmuxSession: String?
    var initialCommand: String?
    var fontName: String = "Menlo"
    @Environment(\.dismiss) private var dismiss
    @State private var isCtrlActive = false
    @State private var isAltActive = false
    @State private var isScrollMode = true
    @State private var isInCopyMode = false
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let optimalFontSize = FontManager.optimalFontSize(
                for: geometry.size.width,
                fontName: fontName
            )

            VStack(spacing: 0) {
                // Top bar
                terminalBar

                // Terminal + Scroll overlay
                ZStack {
                    ShinobiTerminalView(
                        session: session,
                        fontName: fontName,
                        fontSize: optimalFontSize,
                        autoFocus: false
                    )

                    if isScrollMode {
                        ScrollOverlayView { lines in
                            handleScrollGesture(lines: lines)
                        }
                    }
                }

                // Extra Keys
                ExtraKeysView(
                    onKey: { handleExtraKey($0) },
                    isCtrlActive: isCtrlActive,
                    isAltActive: isAltActive,
                    isScrollActive: isScrollMode
                )

                // Input Bar
                InputBarView(
                    text: $inputText,
                    isFocused: $isInputFocused,
                    onSend: { sendInputText() }
                )
            }
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            session.send("export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8\n")
            if let cmd = initialCommand {
                try? await Task.sleep(for: .milliseconds(100))
                session.send(cmd)
            }
            // Auto-enter tmux copy-mode for scroll
            if isScrollMode, tmuxSession != nil {
                try? await Task.sleep(for: .milliseconds(500))
                enterCopyMode()
            }
            isInputFocused = true
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
                if isScrollMode {
                    Text("SCROLL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color("greenPrimary"))
                        .cornerRadius(4)
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

    // MARK: - Copy Mode

    private func enterCopyMode() {
        guard tmuxSession != nil, !isInCopyMode else { return }
        session.send(Data([0x02]))
        session.send(Data("[".utf8))
        isInCopyMode = true
    }

    private func exitCopyMode() {
        guard tmuxSession != nil, isInCopyMode else { return }
        session.send(Data("q".utf8))
        isInCopyMode = false
    }

    // MARK: - Scroll

    private func handleScrollGesture(lines: Int) {
        guard tmuxSession != nil else { return }
        // Enter copy-mode on first scroll if not already in it
        if !isInCopyMode {
            enterCopyMode()
        }
        let arrowUp = Data([0x1B, 0x5B, 0x41])
        let arrowDown = Data([0x1B, 0x5B, 0x42])
        let key = lines > 0 ? arrowUp : arrowDown
        for _ in 0..<abs(lines) {
            session.send(key)
        }
    }

    // MARK: - Input

    private func sendInputText() {
        let text = inputText
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false
        if isScrollMode, tmuxSession != nil {
            // Exit copy-mode if in it, send command, don't re-enter
            exitCopyMode()
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                session.send(text)
                try? await Task.sleep(for: .milliseconds(50))
                session.send(Data([0x0D]))
            }
        } else {
            session.send(text)
            session.send(Data([0x0D]))
        }
    }

    private func toggleScrollMode() {
        isScrollMode.toggle()
        if isScrollMode {
            enterCopyMode()
        } else {
            exitCopyMode()
        }
    }

    private func handleExtraKey(_ key: ExtraKey) {
        switch key {
        case .ctrl:
            isCtrlActive.toggle()
        case .alt:
            isAltActive.toggle()
        case .scroll:
            toggleScrollMode()
        case .keyboard:
            isInputFocused.toggle()
        default:
            if isCtrlActive {
                isCtrlActive = false
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

// MARK: - Scroll Overlay

/// スクロールモード中にパンジェスチャーを検出するオーバーレイ
struct ScrollOverlayView: UIViewRepresentable {
    let onScroll: (Int) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.01)
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    class Coordinator: NSObject {
        let onScroll: (Int) -> Void
        private var accumulatedDelta: CGFloat = 0
        private let lineHeight: CGFloat = 16

        init(onScroll: @escaping (Int) -> Void) {
            self.onScroll = onScroll
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                accumulatedDelta += translation.y
                let lines = Int(accumulatedDelta / lineHeight)
                if lines != 0 {
                    onScroll(-lines)
                    accumulatedDelta -= CGFloat(lines) * lineHeight
                }
                gesture.setTranslation(.zero, in: gesture.view)
            case .ended, .cancelled:
                accumulatedDelta = 0
            default:
                break
            }
        }
    }
}
