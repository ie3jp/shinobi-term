import Citadel
import Foundation
import NIO

enum SSHSessionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

@MainActor
final class SSHSession: ObservableObject {
    @Published var state: SSHSessionState = .disconnected

    private(set) var client: SSHClient?
    private var sessionTask: Task<Void, Never>?

    var onDataReceived: ((Data) -> Void)? {
        didSet {
            // Flush buffered data when callback is registered
            if let callback = onDataReceived, !pendingDataBuffer.isEmpty {
                let buffered = pendingDataBuffer
                pendingDataBuffer.removeAll()
                for data in buffered {
                    callback(data)
                }
            }
        }
    }

    private var pendingDataBuffer: [Data] = []
    private var stdinContinuation: AsyncStream<ByteBuffer>.Continuation?
    private nonisolated(unsafe) var ttyWriter: TTYStdinWriter?
    private var terminalColumns: Int = 80
    private var terminalRows: Int = 24

    func connect(
        hostname: String,
        port: Int,
        username: String,
        password: String
    ) async {
        state = .connecting

        do {
            let client = try await SSHClient.connect(
                host: hostname,
                port: port,
                authenticationMethod: .passwordBased(
                    username: username,
                    password: password
                ),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            self.client = client
            state = .connected
            startPTYSession()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func disconnect() {
        sessionTask?.cancel()
        sessionTask = nil

        stdinContinuation?.finish()
        stdinContinuation = nil
        ttyWriter = nil
        pendingDataBuffer.removeAll()

        let oldClient = client
        client = nil
        Task {
            try? await oldClient?.close()
        }

        state = .disconnected
    }

    func send(_ data: Data) {
        let buffer = ByteBuffer(data: data)
        stdinContinuation?.yield(buffer)
    }

    func send(_ string: String) {
        send(Data(string.utf8))
    }

    func resize(columns: Int, rows: Int) {
        terminalColumns = columns
        terminalRows = rows

        if let writer = ttyWriter {
            Task {
                try? await writer.changeSize(
                    cols: columns,
                    rows: rows,
                    pixelWidth: 0,
                    pixelHeight: 0
                )
            }
        }
    }

    private func startPTYSession() {
        guard let client else { return }

        let (stdinStream, stdinContinuation) = AsyncStream<ByteBuffer>.makeStream()
        self.stdinContinuation = stdinContinuation

        let columns = terminalColumns
        let rows = terminalRows

        sessionTask = Task { [weak self] in
            do {
                try await client.withPTY(
                    .init(
                        wantReply: true,
                        term: "xterm-256color",
                        terminalCharacterWidth: columns,
                        terminalRowHeight: rows,
                        terminalPixelWidth: 0,
                        terminalPixelHeight: 0,
                        terminalModes: .init([
                            .ECHO: 1,
                        ])
                    )
                ) { inbound, outbound in
                    await MainActor.run {
                        self?.ttyWriter = outbound
                    }

                    try await withThrowingTaskGroup(of: Void.self) { group in
                        // Read output from remote
                        group.addTask {
                            for try await output in inbound {
                                let data: Data
                                switch output {
                                case .stdout(var buffer):
                                    guard let bytes = buffer.readData(length: buffer.readableBytes) else { continue }
                                    data = bytes
                                case .stderr(var buffer):
                                    guard let bytes = buffer.readData(length: buffer.readableBytes) else { continue }
                                    data = bytes
                                }
                                await MainActor.run {
                                    if let callback = self?.onDataReceived {
                                        callback(data)
                                    } else {
                                        self?.pendingDataBuffer.append(data)
                                    }
                                }
                            }
                        }

                        // Write input to remote
                        group.addTask {
                            for await buffer in stdinStream {
                                try await outbound.write(buffer)
                            }
                        }

                        try await group.next()
                        group.cancelAll()
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self?.state = .error(error.localizedDescription)
                    }
                }
            }

            if !Task.isCancelled {
                await MainActor.run {
                    self?.state = .disconnected
                    self?.ttyWriter = nil
                }
            }
        }
    }

    deinit {
        sessionTask?.cancel()
        stdinContinuation?.finish()
    }
}
