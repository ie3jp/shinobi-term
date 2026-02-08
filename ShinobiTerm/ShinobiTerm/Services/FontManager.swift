import UIKit

private extension UIFont {
    /// モノスペースフォントの1文字幅を取得
    var monospacedCharWidth: CGFloat {
        let attributes = [NSAttributedString.Key.font: self]
        return ("M" as NSString).size(withAttributes: attributes).width
    }
}

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

    /// 画面幅に応じて最低 targetColumns 列を確保できるフォントサイズを計算
    static func optimalFontSize(
        for screenWidth: CGFloat,
        targetColumns: Int = 80,
        fontName: String = "Menlo"
    ) -> CGFloat {
        let referenceSize: CGFloat = 14
        let referenceFont = terminalFont(name: fontName, size: referenceSize)
        let charWidth = referenceFont.monospacedCharWidth
        let charWidthRatio = charWidth / referenceSize

        let optimalSize = screenWidth / (CGFloat(targetColumns) * charWidthRatio)
        let minimumSize: CGFloat = 7
        let maximumSize: CGFloat = 14
        return min(maximumSize, max(minimumSize, optimalSize.rounded(.down)))
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
