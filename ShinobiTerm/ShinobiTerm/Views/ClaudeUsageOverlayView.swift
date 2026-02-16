import SwiftUI

struct ClaudeUsageOverlayView: View {
    let usage: ClaudeUsage?
    let isLoading: Bool
    var errorMessage: String? = nil
    let onRefresh: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Color("greenPrimary"))
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if let usage {
                usageContent(usage)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("データの取得に失敗しました")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color("textMuted"))
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.red.opacity(0.7))
                            .lineLimit(5)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: 300)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("\u{1F47E} Claude Usage")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color("greenPrimary"))
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("textTertiary"))
                    .frame(width: 28, height: 28)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("textTertiary"))
                    .frame(width: 28, height: 28)
            }
        }
    }

    // MARK: - Usage Content

    @ViewBuilder
    private func usageContent(_ usage: ClaudeUsage) -> some View {
        // Balance — most constrained window
        balanceSection(usage)
            .padding(.top, 12)

        sectionDivider
            .padding(.vertical, 10)

        // Current session (5h rolling window)
        usageSection(
            title: "Current session",
            subtitle: remainingTimeText(usage.fiveHour.resetsAt),
            ratio: usage.fiveHour.utilization / 100.0
        )

        sectionDivider
            .padding(.vertical, 10)

        // All models (weekly)
        usageSection(
            title: "All models",
            subtitle: remainingTimeText(usage.sevenDay.resetsAt),
            ratio: usage.sevenDay.utilization / 100.0
        )

        // Opus weekly (if available)
        if let opus = usage.sevenDayOpus {
            sectionDivider
                .padding(.vertical, 10)

            usageSection(
                title: "Opus",
                subtitle: nil,
                ratio: opus.utilization / 100.0
            )
        }

        // Sonnet weekly (if available)
        if let sonnet = usage.sevenDaySonnet {
            sectionDivider
                .padding(.vertical, 10)

            usageSection(
                title: "Sonnet",
                subtitle: remainingTimeText(sonnet.resetsAt),
                ratio: sonnet.utilization / 100.0
            )
        }
    }

    // MARK: - Balance Section

    private func balanceSection(_ usage: ClaudeUsage) -> some View {
        let maxUtil = max(usage.fiveHour.utilization, usage.sevenDay.utilization)
        let remaining = max(100.0 - maxUtil, 0)
        let color: Color = remaining >= 50 ? .blue : remaining >= 20 ? .orange : .red

        return VStack(alignment: .leading, spacing: 4) {
            Text("現在の残高")
                .font(.system(size: 11))
                .foregroundStyle(Color("textMuted"))
            Text("\(Int(remaining))%")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    // MARK: - Usage Section

    private func usageSection(
        title: String,
        subtitle: String?,
        ratio: Double
    ) -> some View {
        let clampedRatio = min(max(ratio, 0), 1.0)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color("textPrimary"))
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color("textMuted"))
            }
            HStack(spacing: 10) {
                usageBar(ratio: clampedRatio)
                Text("\(Int(clampedRatio * 100))% used")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color("textSecondary"))
                    .fixedSize()
            }
        }
    }

    // MARK: - Progress Bar

    private func usageBar(ratio: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor(for: ratio))
                    .frame(width: max(geo.size.width * ratio, ratio > 0 ? 4 : 0))
            }
        }
        .frame(height: 8)
    }

    private func barColor(for ratio: Double) -> some ShapeStyle {
        if ratio >= 0.8 {
            return LinearGradient(
                colors: [Color.red.opacity(0.7), Color.red],
                startPoint: .leading, endPoint: .trailing
            )
        } else if ratio >= 0.5 {
            return LinearGradient(
                colors: [Color.orange.opacity(0.7), Color.orange],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.blue.opacity(0.7), Color.blue],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    // MARK: - Dividers

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color("borderPrimary").opacity(0.5))
            .frame(height: 0.5)
    }

    // MARK: - Reset Time

    private func remainingTimeText(_ isoString: String?) -> String {
        guard let isoString, let date = parseISO8601(isoString) else { return "" }
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "Reset complete" }
        if remaining <= 60 { return "Resets soon" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        }
        return "Resets in \(minutes)m"
    }

    // MARK: - Formatters

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
            ?? ISO8601DateFormatter().date(from: string)
    }
}
