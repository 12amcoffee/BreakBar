import SwiftUI
import BreakBarCore

/// Everything a Rest / Start working window needs to draw itself.
/// Built from the machine for the live window, or by hand for a settings preview.
struct PromptSpec: Equatable {
    enum Kind { case rest, resting, work }

    var kind: Kind
    var longBreak = false
    var progress: SessionProgress
    var dots: DotProgress
    var endsAt: Date? = nil            // set while resting: shows a countdown
    var total: TimeInterval? = nil     // length of this rest in seconds, for the progress bar (set by the presenter)
    var snoozeMinutes: Int? = nil      // nil: snooze not available
    var extendMinutes: Int? = nil      // nil: extend not available
    var canSkip = false

    /// nil when no window should be showing for this state.
    init?(machine m: TimerMachine) {
        let a = m.available, s = m.settings
        progress = m.sessionProgress
        dots = m.dots
        switch m.state {
        case .awaitingRest(let kind, _, _):
            self.kind = .rest
            longBreak = kind == .long
            snoozeMinutes = a.canSnooze ? s.snoozeMinutes : nil
            canSkip = true
        case .resting(let kind, let end):
            self.kind = .resting
            longBreak = kind == .long
            endsAt = end
            extendMinutes = a.canExtend ? s.extendMinutes : nil
            canSkip = true
        case .awaitingWork(let kind, _):
            self.kind = .work
            longBreak = kind == .long
            extendMinutes = a.canExtend ? s.extendMinutes : nil
        default:
            return nil
        }
    }

    init(kind: Kind, longBreak: Bool = false, progress: SessionProgress, dots: DotProgress,
         endsAt: Date? = nil, total: TimeInterval? = nil,
         snoozeMinutes: Int? = nil, extendMinutes: Int? = nil, canSkip: Bool = false) {
        self.kind = kind; self.longBreak = longBreak; self.progress = progress; self.dots = dots
        self.endsAt = endsAt; self.total = total
        self.snoozeMinutes = snoozeMinutes; self.extendMinutes = extendMinutes; self.canSkip = canSkip
    }
}

struct PromptHandlers {
    var primary: () -> Void = {}       // Start resting / Start working
    var snooze: () -> Void = {}
    var extend: () -> Void = {}
    var skip: () -> Void = {}
    var hide: () -> Void = {}
}

/// What the window's SwiftUI view observes. Updating `spec` redraws an open window in place.
@MainActor
final class PromptModel: ObservableObject {
    @Published var spec: PromptSpec
    var handlers: PromptHandlers

    init(spec: PromptSpec, handlers: PromptHandlers = PromptHandlers()) {
        self.spec = spec
        self.handlers = handlers
    }
}

/// "Session 2 of 4" etc., translated. Shared by the popover and the windows.
func progressText(_ progress: SessionProgress) -> Text {
    switch progress {
    case .session(let current, let n): return Text("Session \(current) of \(n)")
    case .done(let done, let n, let longNext):
        return longNext ? Text("\(done) of \(n) done · long break next") : Text("\(done) of \(n) done")
    case .longBreak: return Text("Long break")
    case .longBreakAfterThisSession: return Text("Long break after this session")
    }
}
