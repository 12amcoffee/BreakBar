import Foundation
import BreakBarCore

/// Appends one JSON object per state change to ~/Library/Application Support/BreakBar/events.jsonl
/// (inside the app's sandbox container). Handy for charting your focus time later.
final class EventLog {
    private struct Entry: Encodable {
        let timestamp: Date
        let event: String
        let from: String
        let to: String
        let completedSessions: Int
    }

    private let url: URL?
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .sortedKeys
        return e
    }()

    init() {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("BreakBar", isDirectory: true) else { url = nil; return }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("events.jsonl")
    }

    func record(event: TimerEvent, from: TimerState, to: TimerState, completedSessions: Int, at date: Date) {
        guard let url, from.name != to.name else { return }      // only real state changes
        let entry = Entry(timestamp: date, event: "\(event)", from: from.name, to: to.name, completedSessions: completedSessions)
        guard var line = try? encoder.encode(entry) else { return }
        line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url)
        }
    }
}
