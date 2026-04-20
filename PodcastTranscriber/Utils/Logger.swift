import Foundation
import Combine

/// A simple logger for the application.
class Logger: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    @Published private(set) var logs: [LogEntry] = []

    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        logs.append(entry)
        objectWillChange.send()
        print("[\(level.rawValue.uppercased())] \(message)")
    }
}

/// Represents a single log entry.
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
}

/// Log levels.
enum LogLevel: String {
    case info
    case error
}
