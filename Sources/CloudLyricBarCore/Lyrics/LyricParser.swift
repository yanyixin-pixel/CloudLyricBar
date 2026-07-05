import Foundation

public enum LyricParser {
    public static func parse(_ raw: String) -> [LyricLine] {
        raw
            .split(whereSeparator: \.isNewline)
            .compactMap(parseLine)
            .sorted { lhs, rhs in
                lhs.startTime < rhs.startTime
            }
    }

    private static func parseLine(_ rawLine: Substring) -> LyricLine? {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

        guard line.hasPrefix("["),
              let tagEnd = line.firstIndex(of: "]")
        else {
            return nil
        }

        let tagStart = line.index(after: line.startIndex)
        let timestamp = line[tagStart..<tagEnd]

        guard let startTime = parseTimestamp(timestamp) else {
            return nil
        }

        let textStart = line.index(after: tagEnd)
        let text = line[textStart...].trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            return nil
        }

        return LyricLine(startTime: startTime, text: text)
    }

    private static func parseTimestamp(_ timestamp: Substring) -> TimeInterval? {
        let parts = timestamp.split(separator: ":", maxSplits: 1)

        guard parts.count == 2,
              let minutes = TimeInterval(parts[0]),
              let seconds = TimeInterval(parts[1]),
              minutes.isFinite,
              seconds.isFinite,
              minutes >= 0,
              seconds >= 0,
              seconds < 60
        else {
            return nil
        }

        return minutes * 60 + seconds
    }
}
