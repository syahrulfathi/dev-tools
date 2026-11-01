import Foundation
import DevToolsCore

// A standalone check runner also works with Command Line Tools, without XCTest.
@main
struct TransformerTests {
    static func main() throws {
        let tests = TransformerTests()
        try tests.testBase64UnicodeRoundTrip()
        try tests.testURLSafeBase64()
        tests.testBase64RejectsMalformedAndBinary()
        try tests.testJSONFormattingMinifyingAndScalars()
        try tests.testYAMLDocumentsAnchorsAndTags()
        try tests.testDiffChangesWhitespaceAndMissingNewline()
        try tests.testLargeSubprocessInputDoesNotDeadlock()
        try tests.testUUIDv7LayoutTimestampAndUniqueness()
        print("PASS: all 8 transformation checks")
    }

    func testUUIDv7LayoutTimestampAndUniqueness() throws {
        // RFC 9562 Appendix A.6 timestamp: 0x017f22e279b0.
        let date = Date(timeIntervalSince1970: 1_645_557_742)
        var generated = Set<String>()
        for _ in 0..<10000 {
            let value = try Transformer.uuidV7(at: date)
            expectEqual(value.count, 36)
            expectTrue(UUID(uuidString: value) != nil)
            let groups = value.split(separator: "-")
            expectEqual(groups.map(\.count), [8, 4, 4, 4, 12])
            expectEqual(String(groups[0] + groups[1]), "017f22e279b0")
            expectTrue(groups[2].hasPrefix("7"))
            expectTrue("89ab".contains(groups[3].first!))
            generated.insert(value)
        }
        expectEqual(generated.count, 10000)
        let epoch = try Transformer.uuidV7(at: Date(timeIntervalSince1970: 0))
        expectTrue(epoch.hasPrefix("00000000-0000-7"))
        let nextMillisecond = try Transformer.uuidV7(at: Date(timeIntervalSince1970: 1_645_557_742.001))
        expectTrue(nextMillisecond.hasPrefix("017f22e2-79b1-7"))
        expectTrue(try Transformer.uuidV7(at: date) < nextMillisecond)
        expectThrows(try Transformer.uuidV7(at: Date(timeIntervalSince1970: -1)))
        expectThrows(try Transformer.uuidV7(at: Date(timeIntervalSince1970: .infinity)))
        expectThrows(try Transformer.uuidV7(at: Date(timeIntervalSince1970: 281_474_976_710.656)))
    }
    func testBase64UnicodeRoundTrip() throws {
        let original = "Hello 👋\nこんにちは\u{0}"
        expectEqual(try Transformer.decodeBase64(Transformer.encodeBase64(original)), original)
        expectEqual(try Transformer.decodeBase64(" SGVs\nbG8= \n"), "Hello")
        expectEqual(try Transformer.decodeBase64(""), "")
    }

    func testURLSafeBase64() throws {
        let original = "🤔\u{FFFF}"
        let encoded = Transformer.encodeBase64(original, urlSafe: true)
        expectFalse(encoded.contains("="))
        expectFalse(encoded.contains("+"))
        expectFalse(encoded.contains("/"))
        expectEqual(try Transformer.decodeBase64(encoded, urlSafe: true), original)
    }

    func testBase64RejectsMalformedAndBinary() {
        expectThrows(try Transformer.decodeBase64("%%%"))
        expectThrows(try Transformer.decodeBase64("abc"))
        expectThrows(try Transformer.decodeBase64("/w=="))
    }

    func testJSONFormattingMinifyingAndScalars() throws {
        let formatted = try Transformer.json("{\"z\":2,\"a\":[true,null,\"日本語\"]}", sortKeys: true)
        expectTrue(formatted.contains("\n"))
        expectTrue(formatted.range(of: "\"a\"")!.lowerBound < formatted.range(of: "\"z\"")!.lowerBound)
        expectEqual(try Transformer.json(formatted, compact: true, sortKeys: true), "{\"a\":[true,null,\"日本語\"],\"z\":2}")
        expectEqual(try Transformer.json("true"), "true")
        expectEqual(try Transformer.json("null"), "null")
        expectThrows(try Transformer.json("{bad}"))
    }

    func testYAMLDocumentsAnchorsAndTags() throws {
        let flow = try Transformer.yaml("x: {a: 1, b: [2,3]}")
        expectFalse(flow.contains("{"))
        expectTrue(flow.contains("  a: 1"))
        let input = "---\nconfig: &defaults\n  enabled: true\ncopy: *defaults\n---\nnote: |\n  hello\n  world\nvalue: !!str 123\n"
        let output = try Transformer.yaml(input)
        expectTrue(output.contains("&defaults"))
        expectTrue(output.contains("*defaults"))
        expectTrue(output.contains("hello"))
        expectTrue(output.contains("!!str"))
        expectEqual(try Transformer.yaml(output), output)
        // Tagged objects remain syntax nodes; they are never deserialized.
        let tagged = try Transformer.yaml("thing: !ruby/object:Object {}\n")
        expectTrue(tagged.contains("!ruby/object:Object"))
        expectThrows(try Transformer.yaml("broken: [1, 2"))
    }

    func testDiffChangesWhitespaceAndMissingNewline() throws {
        let diff = try Transformer.diff("one\ntwo\n", "one\nthree\n")
        expectTrue(diff.contains("-two"))
        expectTrue(diff.contains("+three"))
        expectTrue(diff.contains("--- Original"))
        expectEqual(try Transformer.diff("same", "same"), "No differences found.")
        expectEqual(try Transformer.diff("a b\n", "a  b\n", ignoreWhitespace: true), "No differences found.")
        expectTrue(try Transformer.diff("line", "line\n").contains("No newline"))
        expectTrue(try Transformer.diff("", "added\n").contains("+added"))
    }

    func testLargeSubprocessInputDoesNotDeadlock() throws {
        let input = (0..<10000).map { "key\($0): value\($0)" }.joined(separator: "\n")
        expectTrue(try Transformer.yaml(input).contains("key9999"))
        let left = String(repeating: "old\n", count: 20000)
        let right = String(repeating: "new\n", count: 20000)
        expectTrue(try Transformer.diff(left, right).contains("+new"))
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    guard actual == expected else { fatalError("Expected \(expected), got \(actual)", file: file, line: line) }
}
private func expectTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
    guard value else { fatalError("Expected true", file: file, line: line) }
}
private func expectFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
    expectTrue(!value, file: file, line: line)
}
private func expectThrows<T>(_ operation: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) {
    do { _ = try operation() } catch { return }
    fatalError("Expected an error", file: file, line: line)
}
