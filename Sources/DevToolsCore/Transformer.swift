import Foundation
import Security

public enum ToolFailure: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        switch self { case .message(let value): return value }
    }
}

public enum Transformer {
    /// RFC 9562 §5.7: 48-bit Unix milliseconds and 74 random bits, with version/variant markers.
    public static func uuidV7(at date: Date = Date()) throws -> String {
        let milliseconds = floor(date.timeIntervalSince1970 * 1000)
        guard milliseconds.isFinite, milliseconds >= 0, milliseconds < 281_474_976_710_656 else {
            throw ToolFailure.message("UUID v7 requires a date within its 48-bit Unix millisecond range.")
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw ToolFailure.message("Could not obtain secure random bytes for UUID generation.")
        }
        let timestamp = UInt64(milliseconds)
        for index in 0..<6 {
            bytes[index] = UInt8(truncatingIfNeeded: timestamp >> (8 * (5 - index)))
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x70
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }
        return [hex[0..<4], hex[4..<6], hex[6..<8], hex[8..<10], hex[10..<16]]
            .map { $0.joined() }.joined(separator: "-")
    }

    public static func encodeBase64(_ text: String, urlSafe: Bool = false) -> String {
        let result = Data(text.utf8).base64EncodedString()
        return urlSafe ? result.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") : result
    }

    public static func decodeBase64(_ text: String, urlSafe: Bool = false) throws -> String {
        var value = text.components(separatedBy: .whitespacesAndNewlines).joined()
        if urlSafe {
            value = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            if value.count % 4 != 0 { value += String(repeating: "=", count: 4 - value.count % 4) }
        }
        guard let data = Data(base64Encoded: value) else {
            throw ToolFailure.message("Invalid Base64. Check the input and whether URL-safe mode is needed.")
        }
        guard let decoded = String(data: data, encoding: .utf8) else {
            throw ToolFailure.message("This Base64 contains binary data, not UTF-8 text.")
        }
        return decoded
    }

    public static func json(_ text: String, compact: Bool = false, sortKeys: Bool = false) throws -> String {
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        var options: JSONSerialization.WritingOptions = [.fragmentsAllowed, .withoutEscapingSlashes]
        if !compact { options.insert(.prettyPrinted) }
        if sortKeys { options.insert(.sortedKeys) }
        let data = try JSONSerialization.data(withJSONObject: object, options: options)
        return String(decoding: data, as: UTF8.self)
    }

    public static func yaml(_ text: String) throws -> String {
        guard let script = Bundle.module.url(forResource: "yaml", withExtension: "rb") else {
            throw ToolFailure.message("The bundled YAML helper is missing. Rebuild the app.")
        }
        let result = try run("/usr/bin/ruby", arguments: [script.path], input: text)
        guard result.status == 0 else { throw ToolFailure.message(result.error.isEmpty ? "YAML formatting failed." : result.error) }
        return result.output
    }

    public static func diff(_ original: String, _ modified: String, ignoreWhitespace: Bool = false) throws -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let left = directory.appendingPathComponent("original.txt")
        let right = directory.appendingPathComponent("modified.txt")
        try Data(original.utf8).write(to: left)
        try Data(modified.utf8).write(to: right)
        var arguments = ["-u", "-L", "Original", "-L", "Modified"]
        if ignoreWhitespace { arguments.append("-w") }
        arguments += [left.path, right.path]
        let result = try run("/usr/bin/diff", arguments: arguments, input: "")
        guard result.status <= 1 else { throw ToolFailure.message(result.error) }
        return result.status == 0 ? "No differences found." : result.output
    }

    // Temporary files avoid pipe-buffer deadlocks for large input and output.
    private static func run(_ executable: String, arguments: [String], input: String) throws -> (output: String, error: String, status: Int32) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputURL = directory.appendingPathComponent("in")
        let outputURL = directory.appendingPathComponent("out")
        let errorURL = directory.appendingPathComponent("err")
        try Data(input.utf8).write(to: inputURL)
        try Data().write(to: outputURL)
        try Data().write(to: errorURL)
        let stdin = try FileHandle(forReadingFrom: inputURL)
        let stdout = try FileHandle(forWritingTo: outputURL)
        let stderr = try FileHandle(forWritingTo: errorURL)
        defer { try? stdin.close(); try? stdout.close(); try? stderr.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        return (String(decoding: try Data(contentsOf: outputURL), as: UTF8.self), String(decoding: try Data(contentsOf: errorURL), as: UTF8.self), process.terminationStatus)
    }
}
