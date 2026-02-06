import UIKit

struct FontManager {
    /// CJK フォールバックチェーン付きターミナルフォントを生成
    static func terminalFont(name: String, size: CGFloat) -> UIFont {
        if let font = UIFont(name: name, size: size) {
            return font
        }

        // Fallback chain for CJK support
        let fallbackChain = [
            "Menlo",
            "HiraginoSans-W3",
            "PingFangSC-Regular",
            "PingFangTC-Regular",
            "AppleSDGothicNeo-Regular",
        ]

        for fallbackName in fallbackChain {
            if let font = UIFont(name: fallbackName, size: size) {
                return font
            }
        }

        return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// 利用可能なモノスペースフォント一覧
    static var availableMonospaceFonts: [String] {
        let monoFamilies = [
            "Menlo",
            "Courier New",
            "SF Mono",
            "Hiragino Sans",
            "PingFang SC",
            "PingFang TC",
            "Apple SD Gothic Neo",
        ]

        return monoFamilies.filter { family in
            UIFont.fontNames(forFamilyName: family).isEmpty == false
        }
    }
}
