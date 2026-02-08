import SwiftTerm
import SwiftUI
import UIKit

struct ShinobiTerminalView: UIViewRepresentable {
    let session: SSHSession
    var fontName: String = "Menlo"
    var fontSize: CGFloat = 14
    var scrollbackLines: Int = 10000
    var hapticFeedback: Bool = true
    var autoFocus: Bool = true
    var onSizeChanged: ((Int, Int) -> Void)?

    func makeUIView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: .zero)
        terminalView.backgroundColor = .black
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = UIColor(white: 0.9, alpha: 1.0)

        let font = FontManager.terminalFont(name: fontName, size: fontSize)
        terminalView.font = font

        terminalView.getTerminal().changeHistorySize(scrollbackLines)

        // SwiftTerm 組み込みの inputAccessoryView を無効化（アプリ独自の ExtraKeysView を使用）
        terminalView.inputAccessoryView = nil

        terminalView.terminalDelegate = context.coordinator
        if autoFocus {
            terminalView.becomeFirstResponder()
        }

        context.coordinator.terminalView = terminalView
        context.coordinator.setupDataReceiver()

        return terminalView
    }

    func updateUIView(_ terminalView: TerminalView, context: Context) {
        let font = FontManager.terminalFont(name: fontName, size: fontSize)
        terminalView.font = font
        context.coordinator.hapticFeedback = hapticFeedback
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, hapticFeedback: hapticFeedback, onSizeChanged: onSizeChanged)
    }

    class Coordinator: NSObject, TerminalViewDelegate {
        let session: SSHSession
        var terminalView: TerminalView?
        var hapticFeedback: Bool
        var onSizeChanged: ((Int, Int) -> Void)?
        private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

        init(session: SSHSession, hapticFeedback: Bool, onSizeChanged: ((Int, Int) -> Void)?) {
            self.session = session
            self.hapticFeedback = hapticFeedback
            self.onSizeChanged = onSizeChanged
            super.init()
            hapticGenerator.prepare()
        }

        @MainActor
        func setupDataReceiver() {
            session.onDataReceived = { [weak self] data in
                guard let terminalView = self?.terminalView else { return }
                let bytes = ArraySlice([UInt8](data))
                terminalView.feed(byteArray: bytes)
                // 最下部にスクロールして最新の出力を表示
                let bottomY = max(0, terminalView.contentSize.height - terminalView.bounds.height)
                if terminalView.contentOffset.y < bottomY {
                    terminalView.contentOffset = CGPoint(x: 0, y: bottomY)
                }
            }
        }

        // MARK: - TerminalViewDelegate

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            let sendData = Data(data)
            Task { @MainActor in
                session.send(sendData)
            }
        }

        func scrolled(source: TerminalView, position: Double) {}

        func setTerminalTitle(source: TerminalView, title: String) {}

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            Task { @MainActor in
                session.resize(columns: newCols, rows: newRows)
            }
            onSizeChanged?(newCols, newRows)
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

        func clipboardCopy(source: TerminalView, content: Data) {
            UIPasteboard.general.setData(content, forPasteboardType: "public.utf8-plain-text")
        }

        func bell(source: TerminalView) {
            guard hapticFeedback else { return }
            hapticGenerator.impactOccurred()
            hapticGenerator.prepare()
        }

        func iTermContent(source: TerminalView, content: Data) {}
    }
}
