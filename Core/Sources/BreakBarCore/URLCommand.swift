import Foundation

/// Commands accepted by the `breakbar://` URL scheme, e.g. `open breakbar://startRest`.
public enum URLCommand: Equatable, Sendable {
    case event(TimerEvent)
    case toggle                 // start when idle, otherwise stop

    /// Case-insensitive. Returns nil for unknown commands.
    public init?(host: String) {
        switch host.lowercased() {
        case "start": self = .event(.start)
        case "stop": self = .event(.stop)
        case "toggle", "startstop": self = .toggle
        case "startrest": self = .event(.startRest)
        case "startwork": self = .event(.startWork)
        case "snooze": self = .event(.snooze)
        case "skip": self = .event(.skip)
        case "extend": self = .event(.extend)
        case "pause": self = .event(.pause)
        case "resume": self = .event(.resume)
        case "resetset": self = .event(.resetSet)
        default: return nil
        }
    }

    public init?(url: URL) {
        guard url.scheme?.lowercased() == "breakbar", let host = url.host else { return nil }
        self.init(host: host)
    }
}
