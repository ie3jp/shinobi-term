import Citadel
import Foundation
import NIO

struct ClaudeUsageResult {
    let usage: ClaudeUsage?
    let error: String?
}

struct ClaudeUsageService {

    // Python script that runs entirely on the remote Mac.
    // Reads credentials, calls Usage API, refreshes token on 401, retries.
    private static let remoteScript = #"""
import json, urllib.request, urllib.error, os, sys

CREDS = os.path.expanduser("~/.claude/.credentials.json")
CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
TOKEN_URL = "https://console.anthropic.com/api/oauth/token"

def load_creds():
    with open(CREDS) as f:
        return json.load(f)

def call_usage(token):
    req = urllib.request.Request(USAGE_URL)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("anthropic-beta", "oauth-2025-04-20")
    req.add_header("User-Agent", "claude-code/2.1.5")
    return json.loads(urllib.request.urlopen(req, timeout=10).read())

def refresh(rt):
    body = json.dumps({"grant_type":"refresh_token","refresh_token":rt,"client_id":CLIENT_ID}).encode()
    req = urllib.request.Request(TOKEN_URL, data=body)
    req.add_header("Content-Type", "application/json")
    return json.loads(urllib.request.urlopen(req, timeout=10).read())

try:
    creds = load_creds()
    oauth = creds.get("claudeAiOauth", {})
    token = oauth.get("accessToken", "")
    if not token:
        print(json.dumps({"error": "Mac で Claude Code にログインしてください"}))
        sys.exit(0)

    try:
        print(json.dumps(call_usage(token)))
    except urllib.error.HTTPError as e:
        if e.code != 401:
            print(json.dumps({"error": f"HTTP {e.code}"}))
            sys.exit(0)
        rt = oauth.get("refreshToken", "")
        if not rt:
            print(json.dumps({"error": "refreshToken が見つかりません。claude login を実行してください"}))
            sys.exit(0)
        try:
            new = refresh(rt)
        except urllib.error.HTTPError as e2:
            body = e2.read().decode()[:200] if hasattr(e2, "read") else ""
            print(json.dumps({"error": f"トークン更新失敗 (HTTP {e2.code}): {body}"}))
            sys.exit(0)
        oauth["accessToken"] = new.get("access_token", "")
        if "refresh_token" in new:
            oauth["refreshToken"] = new["refresh_token"]
        creds["claudeAiOauth"] = oauth
        with open(CREDS, "w") as f:
            json.dump(creds, f, indent=2)
        print(json.dumps(call_usage(new["access_token"])))
except Exception as e:
    print(json.dumps({"error": str(e)}))
"""#

    @MainActor
    static func fetchUsage(session: SSHSession) async -> ClaudeUsageResult {
        guard let client = session.client else {
            return ClaudeUsageResult(usage: nil, error: "SSH client not available")
        }

        do {
            var buffer = try await client.executeCommand(
                "python3 -c \(shellEscaped(remoteScript))"
            )
            let output = (buffer.readString(length: buffer.readableBytes) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !output.isEmpty,
                  let data = output.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return ClaudeUsageResult(usage: nil, error: "レスポンスの解析に失敗しました")
            }

            if let error = json["error"] as? String {
                return ClaudeUsageResult(usage: nil, error: error)
            }

            return ClaudeUsageResult(usage: parseUsageResponse(json), error: nil)
        } catch {
            return ClaudeUsageResult(usage: nil, error: "SSH: \(error.localizedDescription)")
        }
    }

    // MARK: - Shell Escape

    private static func shellEscaped(_ script: String) -> String {
        let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
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
        if let s = value as? String, let d = Double(s.replacingOccurrences(of: "%", with: "")) {
            return d
        }
        return 0
    }
}
