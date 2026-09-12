import Foundation

enum ArchiveExtractorError: LocalizedError {
    case unsupportedFormat(String)
    case toolFailed(tool: String, status: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let name):
            return "Unsupported archive format: \(name)"
        case .toolFailed(let tool, let status, let stderr):
            let detail = stderr.isEmpty ? "unknown error" : stderr
            return "\(tool) exited with status \(status): \(detail)"
        }
    }
}

/// Unpacks theme archives with the tools already bundled with macOS, so the
/// app carries no third-party dependencies.
enum ArchiveExtractor {
    private static let ditto = "/usr/bin/ditto"
    private static let tar = "/usr/bin/tar"

    static func extract(_ archive: URL, to destination: URL) throws {
        guard let kind = ArchiveKind.of(archive) else {
            throw ArchiveExtractorError.unsupportedFormat(archive.lastPathComponent)
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        switch kind {
        case .zipFamily:
            try run(ditto, ["-xk", archive.path, destination.path])
        case .tarFamily:
            try run(tar, ["-xf", archive.path, "-C", destination.path])
        }
    }

    private static func run(_ launchPath: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        // Drain before waiting: a tool that writes more than the pipe buffer
        // holds would block forever on a full pipe nobody is reading.
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus != 0 else { return }

        let message = String(data: errorData, encoding: .utf8) ?? ""
        throw ArchiveExtractorError.toolFailed(
            tool: (launchPath as NSString).lastPathComponent,
            status: process.terminationStatus,
            stderr: message.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
