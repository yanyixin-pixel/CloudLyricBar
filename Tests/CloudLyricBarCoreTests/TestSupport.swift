import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}

struct TestCase: Sendable {
    let name: String
    let run: @Sendable () throws -> Void
}

enum TestRegistry {
    static let tests: [TestCase] = playbackModelTests
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String? = nil) throws {
    guard actual == expected else {
        let detail = message ?? "Expected \(expected), got \(actual)"
        throw TestFailure(message: detail)
    }
}

func expectTrue(_ condition: Bool, _ message: String? = nil) throws {
    guard condition else {
        throw TestFailure(message: message ?? "Expected condition to be true")
    }
}

func expectFalse(_ condition: Bool, _ message: String? = nil) throws {
    guard !condition else {
        throw TestFailure(message: message ?? "Expected condition to be false")
    }
}

@main
struct TestRunner {
    static func main() {
        let filter = parsedFilter(from: CommandLine.arguments)
        let tests = TestRegistry.tests.filter { test in
            guard let filter else {
                return true
            }

            return test.name.contains(filter)
        }

        guard !tests.isEmpty else {
            print("No tests matched filter.")
            exit(1)
        }

        var failures = 0

        for test in tests {
            do {
                try test.run()
                print("PASS \(test.name)")
            } catch {
                failures += 1
                print("FAIL \(test.name): \(error)")
            }
        }

        print("\(tests.count - failures)/\(tests.count) tests passed")

        if failures > 0 {
            exit(1)
        }
    }

    private static func parsedFilter(from arguments: [String]) -> String? {
        guard let filterIndex = arguments.firstIndex(of: "--filter") else {
            return nil
        }

        let valueIndex = arguments.index(after: filterIndex)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        return arguments[valueIndex]
    }
}
