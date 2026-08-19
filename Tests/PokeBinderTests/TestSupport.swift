import Foundation

struct ExpectationFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(
    _ condition: Bool,
    _ message: String = "",
    file: String = #fileID,
    line: Int = #line
) throws {
    if !condition {
        let suffix = message.isEmpty ? "" : " — \(message)"
        throw ExpectationFailure(description: "\(file):\(line)\(suffix)")
    }
}

func expectEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    file: String = #fileID,
    line: Int = #line
) throws {
    try expect(actual == expected, "expected \(expected), got \(actual)", file: file, line: line)
}

struct TestCase {
    let name: String
    let run: () async throws -> Void
}

@main
struct PokeBinderTests {
    static func main() async {
        let tests = calculatorTests() + decodingTests() + storeTests() + continuousGridLayoutTests()
        var failed = 0
        for test in tests {
            do {
                try await test.run()
                print("PASS \(test.name)")
            } catch {
                failed += 1
                print("FAIL \(test.name): \(error)")
            }
        }
        print("\(tests.count - failed) passed, \(failed) failed")
        if failed > 0 {
            exit(1)
        }
    }
}
