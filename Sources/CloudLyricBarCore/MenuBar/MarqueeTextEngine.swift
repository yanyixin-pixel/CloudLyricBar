import Foundation

public struct MarqueeFrame: Equatable, Sendable {
    public let text: String
    public let isScrolling: Bool

    public init(text: String, isScrolling: Bool) {
        self.text = text
        self.isScrolling = isScrolling
    }
}

public enum MarqueeTextEngine {
    public static func frame(text: String, visibleCharacterCount: Int, tick: Int) -> MarqueeFrame {
        guard visibleCharacterCount > 0 else {
            return MarqueeFrame(text: "", isScrolling: false)
        }

        let characters = Array(text)
        guard characters.count > visibleCharacterCount else {
            return MarqueeFrame(text: text, isScrolling: false)
        }

        let wrappedCharacters = Array(text + "   ")
        let startIndex = normalizedOffset(tick, count: wrappedCharacters.count)
        let visibleCharacters = (0..<visibleCharacterCount).map { offset in
            wrappedCharacters[(startIndex + offset) % wrappedCharacters.count]
        }

        return MarqueeFrame(text: String(visibleCharacters), isScrolling: true)
    }

    private static func normalizedOffset(_ tick: Int, count: Int) -> Int {
        let offset = tick % count
        return offset >= 0 ? offset : offset + count
    }
}
