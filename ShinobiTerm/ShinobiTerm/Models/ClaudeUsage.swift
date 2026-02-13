import Foundation

struct ClaudeUsage: Codable {
    let fiveHour: UsagePeriod
    let sevenDay: UsagePeriod
    let sevenDayOpus: UsagePeriod?
    let sevenDaySonnet: UsagePeriod?
    let fetchedAt: String
}

struct UsagePeriod: Codable {
    let utilization: Double
    let resetsAt: String?
}
