import Citadel
import Foundation
import NIO

struct TmuxSession: Identifiable {
    let id: String
    let name: String
    let windowCount: Int
    let isAttached: Bool
    let createdAt: String
    let activityAt: TimeInterval

    private static let delimiter = "@@"

    static func parseFormatted(_ line: String) -> TmuxSession? {
        let fields = line.components(separatedBy: delimiter)
        guard fields.count >= 5 else { return nil }

        let name = String(fields[0])
        guard !name.isEmpty else { return nil }

        let windowCount = Int(fields[1]) ?? 1
        let isAttached = (Int(fields[2]) ?? 0) > 0
        let activityAt = TimeInterval(fields[3]) ?? 0
        let createdTimestamp = TimeInterval(fields[4]) ?? 0

        let createdAt: String
        if createdTimestamp > 0 {
            let date = Date(timeIntervalSince1970: createdTimestamp)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            createdAt = formatter.string(from: date)
        } else {
            createdAt = ""
        }

        return TmuxSession(
            id: name,
            name: name,
            windowCount: windowCount,
            isAttached: isAttached,
            createdAt: createdAt,
            activityAt: activityAt
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
            let cmd = "bash -lc 'tmux ls -F \"#{session_name}@@#{session_windows}@@#{session_attached}@@#{session_activity}@@#{session_created}\"' 2>/dev/null || true"
            var buffer = try await client.executeCommand(cmd)
            let output = buffer.readString(length: buffer.readableBytes) ?? ""

            let sessions: [TmuxSession] = output.split(separator: "\n").compactMap { line in
                let lineStr = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !lineStr.isEmpty else { return nil }
                return TmuxSession.parseFormatted(lineStr)
            }

            return sessions.sorted { $0.activityAt > $1.activityAt }
        } catch {
            return []
        }
    }
}
