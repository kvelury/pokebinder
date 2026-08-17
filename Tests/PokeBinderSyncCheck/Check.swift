import Foundation

/// Tiny assertion helper. Command Line Tools has no XCTest on this machine.
enum Check {
    private(set) static var failures = 0

    static func expect(
        _ condition: Bool,
        _ message: String,
        file: String = #fileID,
        line: Int = #line
    ) {
        guard !condition else { return }
        failures += 1
        FileHandle.standardError.write(Data("FAIL \(file):\(line): \(message)\n".utf8))
    }

    static func equal<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ message: String = "",
        file: String = #fileID,
        line: Int = #line
    ) {
        let detail = message.isEmpty ? "\(actual) != \(expected)" : "\(message) (\(actual) != \(expected))"
        expect(actual == expected, detail, file: file, line: line)
    }

    static func isNil<T>(
        _ value: T?,
        _ message: String = "expected nil",
        file: String = #fileID,
        line: Int = #line
    ) {
        expect(value == nil, message, file: file, line: line)
    }

    @discardableResult
    static func notNil<T>(
        _ value: T?,
        _ message: String = "expected a value",
        file: String = #fileID,
        line: Int = #line
    ) -> T? {
        expect(value != nil, message, file: file, line: line)
        return value
    }
}
