import Foundation

public struct MarqueeFrame: Equatable, Sendable {
    public let text: String
    public let isScrolling: Bool

    public init(text: String, isScrolling: Bool) {
        self.text = text
        self.isScrolling = isScrolling
    }
}

public struct MarqueeTitleState: Equatable, Sendable {
    public private(set) var title: String
    public private(set) var tick: Int

    public init(title: String = "♪", tick: Int = 0) {
        self.title = title
        self.tick = tick
    }

    public mutating func updateTitle(_ newTitle: String) {
        guard newTitle != title else {
            return
        }

        title = newTitle
        tick = 0
    }

    public mutating func advance() {
        tick += 1
    }

    public func frame(
        visibleCharacterCount: Int,
        leadingPauseTicks: Int,
        trailingPauseTicks: Int
    ) -> MarqueeFrame {
        MarqueeTextEngine.pausedFrame(
            text: title,
            visibleCharacterCount: visibleCharacterCount,
            tick: tick,
            leadingPauseTicks: leadingPauseTicks,
            trailingPauseTicks: trailingPauseTicks
        )
    }

    public func pixelFrame(
        maxDisplayWidth: Double,
        leadingPauseTicks: Int,
        trailingPauseTicks: Int,
        characterWidth: (Character) -> Double
    ) -> MarqueeFrame {
        MarqueeTextEngine.pixelFrame(
            text: title,
            maxDisplayWidth: maxDisplayWidth,
            tick: tick,
            leadingPauseTicks: leadingPauseTicks,
            trailingPauseTicks: trailingPauseTicks,
            characterWidth: characterWidth
        )
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

    public static func pausedFrame(
        text: String,
        visibleCharacterCount: Int,
        tick: Int,
        leadingPauseTicks: Int,
        trailingPauseTicks: Int
    ) -> MarqueeFrame {
        guard visibleCharacterCount > 0 else {
            return MarqueeFrame(text: "", isScrolling: false)
        }

        let characters = Array(text)
        guard characters.count > visibleCharacterCount else {
            return MarqueeFrame(text: text, isScrolling: false)
        }

        let maxOffset = characters.count - visibleCharacterCount
        let leadingPause = max(0, leadingPauseTicks)
        let trailingPause = max(0, trailingPauseTicks)
        let cycleLength = max(1, leadingPause + maxOffset + trailingPause)
        let phase = normalizedOffset(tick, count: cycleLength)
        let startIndex: Int

        if phase < leadingPause {
            startIndex = 0
        } else {
            let shifted = phase - leadingPause + 1
            startIndex = min(maxOffset, shifted)
        }

        let visibleCharacters = (0..<visibleCharacterCount).map { offset in
            characters[startIndex + offset]
        }

        return MarqueeFrame(text: String(visibleCharacters), isScrolling: true)
    }

    public static func pixelFrame(
        text: String,
        maxDisplayWidth: Double,
        tick: Int,
        leadingPauseTicks: Int,
        trailingPauseTicks: Int,
        characterWidth: (Character) -> Double
    ) -> MarqueeFrame {
        guard maxDisplayWidth > 0 else {
            return MarqueeFrame(text: "", isScrolling: false)
        }

        let characters = Array(text)
        guard !characters.isEmpty else {
            return MarqueeFrame(text: "", isScrolling: false)
        }

        let totalWidth = characters.reduce(0) { total, character in
            total + max(0, characterWidth(character))
        }
        guard totalWidth > maxDisplayWidth else {
            return MarqueeFrame(text: text, isScrolling: false)
        }

        let maxStartIndex = max(0, characters.count - 1)
        let leadingPause = max(0, leadingPauseTicks)
        let trailingPause = max(0, trailingPauseTicks)
        let cycleLength = max(1, leadingPause + maxStartIndex + 1 + trailingPause)
        let phase = normalizedOffset(tick, count: cycleLength)
        let startIndex = min(maxStartIndex, max(0, phase - leadingPause))
        var width = 0.0
        var visibleCharacters: [Character] = []

        for character in characters[startIndex...] {
            let nextWidth = width + max(0, characterWidth(character))
            if !visibleCharacters.isEmpty, nextWidth > maxDisplayWidth {
                break
            }

            visibleCharacters.append(character)
            width = nextWidth
        }

        return MarqueeFrame(text: String(visibleCharacters), isScrolling: true)
    }

    private static func normalizedOffset(_ tick: Int, count: Int) -> Int {
        let offset = tick % count
        return offset >= 0 ? offset : offset + count
    }
}
