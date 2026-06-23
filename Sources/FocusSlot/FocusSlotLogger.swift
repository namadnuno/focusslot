import Foundation

enum FocusSlotLogger {
    private static let queue = DispatchQueue(label: "FocusSlotLogger")

    static var logFileURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("FocusSlot", isDirectory: true)
            .appendingPathComponent("FocusSlot.log")
    }

    static func log(_ message: String) {
        let line = "[\(Self.timestamp())] \(message)\n"
        NSLog("FocusSlot: %@", message)

        queue.async {
            do {
                let directoryURL = logFileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

                if let data = line.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: logFileURL.path) {
                        let handle = try FileHandle(forWritingTo: logFileURL)
                        try handle.seekToEnd()
                        try handle.write(contentsOf: data)
                        try handle.close()
                    } else {
                        try data.write(to: logFileURL)
                    }
                }
            } catch {
                NSLog("FocusSlot logger failed: %@", error.localizedDescription)
            }
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
