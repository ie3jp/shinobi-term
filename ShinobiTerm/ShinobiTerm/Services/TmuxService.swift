import Citadel
import Foundation
import NIO

struct TmuxSession: Identifiable {
    let id: String
    let name: String
    let windowCount: Int
    let isAttached: Bool
    let createdAt: String

    static func parseLine(_ line: String) -> TmuxSession? {
        let parts = line.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let rest = String(parts[1]).trimmingCharacters(in: .whitespaces)

        guard rest.contains("window") else { return nil }

        var windowCount = 1
        if let windowMatch = rest.range(of: #"(\d+) windows?"#, options: .regularExpression) {
            let countStr = rest[windowMatch].split(separator: " ").first.map(String.init) ?? "1"
            windowCount = Int(countStr) ?? 1
        }

        let isAttached = rest.contains("(attached)")

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
    @MainActor
    static func listSessions(session: SSHSession) async -> [TmuxSession] {
        guard let client = session.client else {
            return []
        }

        do {
            var buffer = try await client.executeCommand("bash -lc 'tmux ls' 2>/dev/null || true")
            let output = buffer.readString(length: buffer.readableBytes) ?? ""

            return output.split(separator: "\n").compactMap { line in
                let lineStr = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !lineStr.isEmpty else { return nil }
                return TmuxSession.parseLine(lineStr)
            }
        } catch {
            return []
        }
    }
}
