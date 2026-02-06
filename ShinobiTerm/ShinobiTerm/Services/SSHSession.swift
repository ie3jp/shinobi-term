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

    private var client: SSHClient?
    private var sessionTask: Task<Void, Never>?

    var onDataReceived: ((Data) -> Void)?

    private var stdinContinuation: AsyncStream<ByteBuffer>.Continuation?
    private var terminalColumns: UInt32 = 80
    private var terminalRows: UInt32 = 24

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

        Task {
            try? await client?.close()
            client = nil
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
        terminalColumns = UInt32(columns)
        terminalRows = UInt32(rows)
        // Note: Citadel doesn't expose window change request directly.
        // Terminal resize will take effect on next PTY session.
        // For dynamic resize, we may need to access the underlying NIO channel.
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
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        // Read output from remote
                        group.addTask {
                            for try await var buffer in inbound {
                                guard let data = buffer.readData(length: buffer.readableBytes) else {
                                    continue
                                }
                                await MainActor.run {
                                    self?.onDataReceived?(data)
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
                }
            }
        }
    }

    deinit {
        sessionTask?.cancel()
        stdinContinuation?.finish()
    }
}
