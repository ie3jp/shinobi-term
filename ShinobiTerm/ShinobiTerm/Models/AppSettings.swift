import Foundation
import SwiftData

@Model
final class AppSettings {
    var fontName: String
    var fontSize: Double
    var colorScheme: String
    var scrollbackLines: Int
    var bellSound: Bool
    var hapticFeedback: Bool

    init(
        fontName: String = "Menlo",
        fontSize: Double = 14.0,
        colorScheme: String = "Shinobi Dark",
        scrollbackLines: Int = 10000,
        bellSound: Bool = true,
        hapticFeedback: Bool = true
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.colorScheme = colorScheme
        self.scrollbackLines = scrollbackLines
        self.bellSound = bellSound
        self.hapticFeedback = hapticFeedback
    }
}
