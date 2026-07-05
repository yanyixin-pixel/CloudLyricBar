import CloudLyricBarCore
import Foundation

let lyricSyncEngineTests: [TestCase] = [
    TestCase(
        name: "LyricSyncEngineTests.testReturnsCurrentPreviousAndNextLine",
        run: LyricSyncEngineTests.testReturnsCurrentPreviousAndNextLine
    ),
    TestCase(
        name: "LyricSyncEngineTests.testBeforeFirstLineReturnsFirstAsNext",
        run: LyricSyncEngineTests.testBeforeFirstLineReturnsFirstAsNext
    )
]

enum LyricSyncEngineTests {
    static func testReturnsCurrentPreviousAndNextLine() throws {
        let lines = [
            LyricLine(startTime: 1, text: "第一句"),
            LyricLine(startTime: 3, text: "第二句"),
            LyricLine(startTime: 8, text: "第三句")
        ]

        let context = LyricSyncEngine.context(at: 5, in: lines)

        try expectEqual(context.previous, LyricLine(startTime: 1, text: "第一句"))
        try expectEqual(context.current, LyricLine(startTime: 3, text: "第二句"))
        try expectEqual(context.next, LyricLine(startTime: 8, text: "第三句"))
    }

    static func testBeforeFirstLineReturnsFirstAsNext() throws {
        let first = LyricLine(startTime: 10, text: "还没开始")
        let context = LyricSyncEngine.context(at: 5, in: [first])

        try expectEqual(context.previous, nil)
        try expectEqual(context.current, nil)
        try expectEqual(context.next, first)
    }
}
