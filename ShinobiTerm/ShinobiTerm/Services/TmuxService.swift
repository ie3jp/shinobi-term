import Foundation

struct TmuxSession: Identifiable {
    let id: String
    let name: String
    let windowCount: Int
    let isAttached: Bool
    let createdAt: String

    static func parse(from output: String) -> [TmuxSession] {
        output.split(separator: "\n").compactMap { line in
            parseLine(String(line))
        }
    }

    /// Parse a line from `tmux ls` output
    /// Format: "session_name: N windows (created Mon Jan  1 12:00:00 2025) (attached)"
    private static func parseLine(_ line: String) -> TmuxSession? {
        let parts = line.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let rest = String(parts[1]).trimmingCharacters(in: .whitespaces)

        // Extract window count
        var windowCount = 1
        if let windowMatch = rest.range(of: #"(\d+) windows?"#, options: .regularExpression) {
            let countStr = rest[windowMatch].split(separator: " ").first.map(String.init) ?? "1"
            windowCount = Int(countStr) ?? 1
        }

        let isAttached = rest.contains("(attached)")

        // Extract creation time
        var createdAt = ""
        if let createdRange = rest.range(of: #"\(created (.+?)\)"#, options: .regularExpression) {
            let match = String(rest[createdRange])
            createdAt = match
                .replacingOccurrences(of: "(created ", with: "")
                .replacingOccurrences(of: ")", with: "")
        }

        return TmuxSession(
            id: name,
            name: name,
            windowCount: windowCount,
            isAttached: isAttached,
            createdAt: createdAt
        )
    }
}

struct TmuxService {
    /// Execute `tmux ls` via the SSH session and return parsed sessions
    @MainActor
    static func listSessions(session: SSHSession) async -> [TmuxSession] {
        var outputData = Data()
        let previousHandler = session.onDataReceived

        // Temporarily capture output
        session.onDataReceived = { data in
            outputData.append(data)
        }

        // Send tmux ls command
        session.send("tmux ls 2>/dev/null\n")

        // Wait for response
        try? await Task.sleep(for: .seconds(2))

        // Restore previous handler
        session.onDataReceived = previousHandler

        guard let outputString = String(data: outputData, encoding: .utf8) else {
            return []
        }

        return TmuxSession.parse(from: outputString)
    }
}
