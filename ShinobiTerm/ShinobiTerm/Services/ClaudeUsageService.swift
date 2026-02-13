import Citadel
import Foundation
import NIO

struct ClaudeUsageResult {
    let usage: ClaudeUsage?
    let error: String?
}

struct ClaudeUsageService {

    @MainActor
    static func fetchUsage(session: SSHSession) async -> ClaudeUsageResult {
        guard let client = session.client else {
            return ClaudeUsageResult(usage: nil, error: "SSH client not available")
        }

        // Step 1: Get OAuth token from remote via SSH
        let tokenResult = await fetchOAuthToken(client: client)
        guard let token = tokenResult.token else {
            return ClaudeUsageResult(usage: nil, error: tokenResult.error ?? "No token")
        }

        // Step 2: Call the API directly from iOS
        return await callUsageAPI(token: token)
    }

    // MARK: - Step 1: Get OAuth Token via SSH

    private struct TokenResult {
        let token: String?
        let error: String?
    }

    private static func fetchOAuthToken(client: SSHClient) async -> TokenResult {
        do {
            var buffer = try await client.executeCommand("cat ~/.claude/.credentials.json 2>/dev/null")
            let output = (buffer.readString(length: buffer.readableBytes) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !output.isEmpty,
                  let data = output.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let oauth = json["claudeAiOauth"] as? [String: Any],
                  let token = oauth["accessToken"] as? String, !token.isEmpty
            else {
                return TokenResult(token: nil, error: "Mac で Claude Code にログインしてください")
            }

            return TokenResult(token: token, error: nil)
        } catch {
            return TokenResult(token: nil, error: "SSH: \(error.localizedDescription)")
        }
    }

    // MARK: - Step 2: Call Usage API directly from iOS

    private static func callUsageAPI(token: String) async -> ClaudeUsageResult {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            return ClaudeUsageResult(usage: nil, error: "Bad URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.1.5", forHTTPHeaderField: "User-Agent")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                return ClaudeUsageResult(usage: nil, error: "No HTTP response")
            }

            guard http.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8)?.prefix(100) ?? ""
                return ClaudeUsageResult(usage: nil, error: "HTTP \(http.statusCode): \(body)")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return ClaudeUsageResult(usage: nil, error: "Invalid JSON")
            }

            return ClaudeUsageResult(usage: parseUsageResponse(json), error: nil)
        } catch {
            return ClaudeUsageResult(usage: nil, error: "API: \(error.localizedDescription)")
        }
    }

    // MARK: - Parse API Response

    private static func parseUsageResponse(_ json: [String: Any]) -> ClaudeUsage {
        func parsePeriod(_ key: String) -> UsagePeriod? {
            guard let dict = json[key] as? [String: Any] else { return nil }
            let util = parseUtilization(dict["utilization"])
            let resetsAt = dict["resets_at"] as? String
            return UsagePeriod(utilization: util, resetsAt: resetsAt)
        }

        let now = ISO8601DateFormatter().string(from: Date())

        return ClaudeUsage(
            fiveHour: parsePeriod("five_hour") ?? UsagePeriod(utilization: 0, resetsAt: nil),
            sevenDay: parsePeriod("seven_day") ?? UsagePeriod(utilization: 0, resetsAt: nil),
            sevenDayOpus: parsePeriod("seven_day_opus"),
            sevenDaySonnet: parsePeriod("seven_day_sonnet"),
            fetchedAt: now
        )
    }

    private static func parseUtilization(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String, let d = Double(s.replacingOccurrences(of: "%", with: "")) { return d }
        return 0
    }
}
