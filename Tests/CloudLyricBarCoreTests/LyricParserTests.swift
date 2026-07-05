import CloudLyricBarCore
import Foundation

let lyricParserTests: [TestCase] = [
    TestCase(
        name: "LyricParserTests.testParsesLrcLinesAndSortsByTime",
        run: LyricParserTests.testParsesLrcLinesAndSortsByTime
    ),
    TestCase(
        name: "LyricParserTests.testSkipsMetadataAndBlankLyricLines",
        run: LyricParserTests.testSkipsMetadataAndBlankLyricLines
    ),
    TestCase(
        name: "LyricParserTests.testSkipsMalformedTimestamps",
        run: LyricParserTests.testSkipsMalformedTimestamps
    )
]

enum LyricParserTests {
    static func testParsesLrcLinesAndSortsByTime() throws {
        let raw = """
        [01:02.03]一分钟后的歌词
        [00:12.50]第一句歌词
        """

        let lines = LyricParser.parse(raw)

        try expectEqual(
            lines,
            [
                LyricLine(startTime: 12.5, text: "第一句歌词"),
                LyricLine(startTime: 62.03, text: "一分钟后的歌词")
            ]
        )
    }

    static func testSkipsMetadataAndBlankLyricLines() throws {
        let raw = """
        [ar:Artist]
        [ti:Title]
        [00:01.00]
        [00:02.00]保留这一句
        """

        let lines = LyricParser.parse(raw)

        try expectEqual(lines, [LyricLine(startTime: 2, text: "保留这一句")])
    }

    static func testSkipsMalformedTimestamps() throws {
        let raw = """
        [nan:01.00]x
        [inf:01.00]x
        [-01:02.00]x
        [00:60.00]x
        [00:03.00]valid
        """

        let lines = LyricParser.parse(raw)

        try expectEqual(lines, [LyricLine(startTime: 3, text: "valid")])
    }
}
