import SwiftTerm
import SwiftUI
import UIKit

struct ShinobiTerminalView: UIViewRepresentable {
    let session: SSHSession
    var fontName: String = "Menlo"
    var fontSize: CGFloat = 14
    var onSizeChanged: ((Int, Int) -> Void)?

    func makeUIView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: .zero)
        terminalView.backgroundColor = .black
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = UIColor(white: 0.9, alpha: 1.0)

        let font = FontManager.terminalFont(name: fontName, size: fontSize)
        terminalView.font = font

        terminalView.terminalDelegate = context.coordinator
        terminalView.becomeFirstResponder()

        context.coordinator.terminalView = terminalView
        context.coordinator.setupDataReceiver()

        return terminalView
    }

    func updateUIView(_ terminalView: TerminalView, context: Context) {
        let font = FontManager.terminalFont(name: fontName, size: fontSize)
        terminalView.font = font
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, onSizeChanged: onSizeChanged)
    }

    class Coordinator: NSObject, TerminalViewDelegate {
        let session: SSHSession
        var terminalView: TerminalView?
        var onSizeChanged: ((Int, Int) -> Void)?

        init(session: SSHSession, onSizeChanged: ((Int, Int) -> Void)?) {
            self.session = session
            self.onSizeChanged = onSizeChanged
        }

        func setupDataReceiver() {
            session.onDataReceived = { [weak self] data in
                guard let terminalView = self?.terminalView else { return }
                let bytes = [UInt8](data)
                terminalView.feed(byteArray: bytes)
            }
        }

        // MARK: - TerminalViewDelegate

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            let sendData = Data(data)
            session.send(sendData)
        }

        func scrolled(source: TerminalView, position: Double) {}

        func setTerminalTitle(source: TerminalView, title: String) {}

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            session.resize(columns: newCols, rows: newRows)
            onSizeChanged?(newCols, newRows)
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

        func clipboardCopy(source: TerminalView, content: Data) {
            UIPasteboard.general.setData(content, forPasteboardType: "public.utf8-plain-text")
        }

        func iTermContent(source: TerminalView, content: Data) {}
    }
}
