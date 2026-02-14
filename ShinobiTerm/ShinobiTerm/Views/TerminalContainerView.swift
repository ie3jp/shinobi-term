import SwiftData
import SwiftTerm
import SwiftUI

// MARK: - ANSI Sequences

private enum ANSI {
    static let arrowUp = Data([0x1B, 0x5B, 0x41])
    static let arrowDown = Data([0x1B, 0x5B, 0x42])
    static let tmuxPrefix = Data([0x02])
}

// MARK: - Terminal Container

struct TerminalContainerView: View {
    let session: SSHSession
    let profileName: String
    var tmuxSession: String?
    var initialCommand: String?
    var fontName: String = "Menlo"

    @Environment(\.dismiss) private var dismiss
    @Query private var allSettings: [AppSettings]

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    // Modifier keys
    @State private var isCtrlActive = false
    @State private var isAltActive = false

    // Read mode
    @State private var isReadMode = false
    @State private var isInCopyMode = false
    @State private var scrollLinesFromBottom = 0

    // Zoom
    @State private var terminalScale: CGFloat = 1.0
    @State private var terminalOffset: CGSize = .zero

    // Terminal
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    // Claude Usage
    @State private var isClaudeUsageVisible = false
    @State private var claudeUsage: ClaudeUsage?
    @State private var isLoadingUsage = false
    @State private var claudeUsageError: String?

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                terminalBar

                ZStack {
                    ShinobiTerminalView(
                        session: session,
                        fontName: fontName,
                        fontSize: settings.fontSize,
                        scrollbackLines: settings.scrollbackLines,
                        hapticFeedback: settings.hapticFeedback,
                        autoFocus: false
                    )
                    .scaleEffect(terminalScale)
                    .offset(terminalOffset)

                    if isReadMode {
                        ScrollOverlayView(
                            isZoomed: terminalScale > 1.0,
                            onScroll: { handleScrollGesture(lines: $0) },
                            onScrollEnded: { handleScrollEnded() },
                            onPinch: { handlePinchGesture(scale: $0) },
                            onZoomPan: { handleZoomPan(translation: $0) },
                            onDoubleTap: { resetZoom() }
                        )

                        VStack {
                            Spacer()
                            readModeControls
                        }
                        .padding(.bottom, 8)
                    }

                    if isClaudeUsageVisible {
                        VStack {
                            Spacer()
                            ClaudeUsageOverlayView(
                                usage: claudeUsage,
                                isLoading: isLoadingUsage,
                                errorMessage: claudeUsageError,
                                onRefresh: { fetchClaudeUsage() },
                                onDismiss: { isClaudeUsageVisible = false }
                            )
                        }
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                }
                .clipped()

                ExtraKeysView(
                    onKey: { handleExtraKey($0) },
                    isCtrlActive: isCtrlActive,
                    isAltActive: isAltActive,
                    isReadActive: isReadMode,
                    isClaudeActive: isClaudeUsageVisible
                )

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
            isInputFocused = true
        }
    }

    // MARK: - Top Bar

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
                if isReadMode {
                    Text("READ")
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

    // MARK: - Read Mode Controls

    private var readModeControls: some View {
        VStack(spacing: 8) {
            // Font size controls
            HStack(spacing: 12) {
                Button {
                    if settings.fontSize > 8 { settings.fontSize -= 1 }
                } label: {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            settings.fontSize <= 8 ? Color("textTertiary") : Color("textPrimary")
                        )
                }
                .disabled(settings.fontSize <= 8)

                Text("\(Int(settings.fontSize))px")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color("textMuted"))
                    .monospacedDigit()
                    .frame(minWidth: 32)

                Button {
                    if settings.fontSize < 32 { settings.fontSize += 1 }
                } label: {
                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            settings.fontSize >= 32 ? Color("textTertiary") : Color("textPrimary")
                        )
                }
                .disabled(settings.fontSize >= 32)
            }

            // Zoom controls
            HStack(spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        terminalScale = max(1.0, terminalScale - 0.5)
                        if terminalScale <= 1.0 { terminalOffset = .zero }
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            terminalScale <= 1.0 ? Color("textTertiary") : Color("textPrimary")
                        )
                }
                .disabled(terminalScale <= 1.0)

                if terminalScale > 1.0 {
                    Text("\(Int(terminalScale * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("textMuted"))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        terminalScale = min(4.0, terminalScale + 0.5)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            terminalScale >= 4.0 ? Color("textTertiary") : Color("textPrimary")
                        )
                }
                .disabled(terminalScale >= 4.0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - tmux Copy Mode

    private func enterCopyMode() {
        guard tmuxSession != nil, !isInCopyMode else { return }
        session.send(ANSI.tmuxPrefix)
        session.send(Data("[".utf8))
        isInCopyMode = true
    }

    private func exitCopyMode() {
        guard tmuxSession != nil, isInCopyMode else { return }
        session.send(Data("q".utf8))
        isInCopyMode = false
    }

    private func returnToLiveView() {
        exitCopyMode()
        scrollLinesFromBottom = 0
    }

    // MARK: - Zoom

    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            terminalScale = 1.0
            terminalOffset = .zero
        }
    }

    private func handlePinchGesture(scale: CGFloat) {
        let newScale = terminalScale * scale
        terminalScale = max(1.0, min(4.0, newScale))
        if terminalScale <= 1.0 {
            terminalOffset = .zero
        }
    }

    private func handleZoomPan(translation: CGPoint) {
        guard terminalScale > 1.0 else { return }
        terminalOffset = CGSize(
            width: terminalOffset.width + translation.x,
            height: terminalOffset.height + translation.y
        )
    }

    // MARK: - Scroll

    private func handleScrollGesture(lines: Int) {
        guard tmuxSession != nil else { return }
        if !isInCopyMode {
            enterCopyMode()
        }
        scrollLinesFromBottom = max(0, scrollLinesFromBottom + lines)
        let key = lines > 0 ? ANSI.arrowUp : ANSI.arrowDown
        for _ in 0..<abs(lines) {
            session.send(key)
        }
    }

    private func handleScrollEnded() {
        if scrollLinesFromBottom <= 0, isInCopyMode {
            exitCopyMode()
        }
    }

    // MARK: - Input

    private func sendInputText() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false

        if isInCopyMode, tmuxSession != nil {
            returnToLiveView()
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                session.send(text)
                try? await Task.sleep(for: .milliseconds(50))
                session.send(Data([0x0D]))
            }
        } else {
            Task {
                session.send(text)
                try? await Task.sleep(for: .milliseconds(50))
                session.send(Data([0x0D]))
            }
        }
    }

    // MARK: - Mode Toggle

    private func toggleReadMode() {
        isReadMode.toggle()
        if isReadMode {
            scrollLinesFromBottom = 0
        } else {
            returnToLiveView()
            resetZoom()
        }
    }

    // MARK: - Claude Usage

    private func toggleClaudeUsage() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isClaudeUsageVisible.toggle()
        }
        if isClaudeUsageVisible {
            fetchClaudeUsage()
        }
    }

    private func fetchClaudeUsage() {
        guard !isLoadingUsage else { return }
        isLoadingUsage = true
        claudeUsageError = nil
        Task {
            let result = await ClaudeUsageService.fetchUsage(session: session)
            claudeUsage = result.usage
            claudeUsageError = result.error
            isLoadingUsage = false
        }
    }

    // MARK: - Extra Keys

    private func handleExtraKey(_ key: ExtraKey) {
        switch key {
        case .ctrl:
            isCtrlActive.toggle()
        case .alt:
            isAltActive.toggle()
        case .read:
            toggleReadMode()
        case .keyboard:
            isInputFocused.toggle()
        case .claude:
            toggleClaudeUsage()
        default:
            if isCtrlActive {
                isCtrlActive = false
                if let char = key.label.lowercased().first,
                   let ascii = char.asciiValue {
                    session.send(Data([ascii & 0x1F]))
                } else {
                    session.send(key.sequence)
                }
            } else {
                session.send(key.sequence)
            }
        }
    }
}
