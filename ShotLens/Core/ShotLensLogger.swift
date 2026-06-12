import Foundation

enum ShotLensLogger {
    private static let queue = DispatchQueue(label: "ShotLensLogger")

    static func log(
        _ message: String,
        error: Error? = nil,
        function: String = #function,
        line: Int = #line
    ) {
        let errorText = error.map { " | error=\($0.localizedDescription)" } ?? ""
        let entry = "\(ISO8601DateFormatter().string(from: Date())) [\(function):\(line)] \(message)\(errorText)\n"

        NSLog("[ShotLens] \(message)\(errorText)")

        queue.async {
            let fileManager = FileManager.default
            let logDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/ShotLens", isDirectory: true)
            let logFile = logDirectory.appendingPathComponent("ShotLens.log")

            do {
                try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
                if !fileManager.fileExists(atPath: logFile.path) {
                    fileManager.createFile(atPath: logFile.path, contents: nil)
                }

                let handle = try FileHandle(forWritingTo: logFile)
                handle.seekToEndOfFile()
                handle.write(Data(entry.utf8))
                try handle.close()
            } catch {
                NSLog("[ShotLens] 日志写入失败: \(error.localizedDescription)")
            }
        }
    }
}
