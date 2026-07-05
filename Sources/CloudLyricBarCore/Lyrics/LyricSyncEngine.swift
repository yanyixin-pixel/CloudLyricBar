import Foundation

public enum LyricSyncEngine {
    public static func context(at position: TimeInterval, in lines: [LyricLine]) -> LyricContext {
        guard !lines.isEmpty else {
            return LyricContext(previous: nil, current: nil, next: nil)
        }

        guard let currentIndex = lines.lastIndex(where: { $0.startTime <= position }) else {
            return LyricContext(previous: nil, current: nil, next: lines.first)
        }

        let previousIndex = lines.index(currentIndex, offsetBy: -1, limitedBy: lines.startIndex)
        let nextIndex = lines.index(currentIndex, offsetBy: 1, limitedBy: lines.index(before: lines.endIndex))

        return LyricContext(
            previous: previousIndex.map { lines[$0] },
            current: lines[currentIndex],
            next: nextIndex.map { lines[$0] }
        )
    }
}
