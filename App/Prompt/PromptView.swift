import SwiftUI
import BreakBarCore

/// The content of every Rest / Start working window. `style` only changes size and layout.
struct PromptView: View {
    @ObservedObject var model: PromptModel
    let style: PromptWindowStyle

    private var spec: PromptSpec { model.spec }
    private var h: PromptHandlers { model.handlers }

    var body: some View {
        switch style {
        case .banner:
            banner
        case .fullScreen:
            ZStack {
                Color.black.opacity(0.88)
                card
            }
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .ignoresSafeArea()
        case .small, .maximised:
            card
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    // MARK: Layouts

    private var scale: CGFloat {
        switch style {
        case .small, .banner: return 1
        case .maximised: return 1.8
        case .fullScreen: return 2.2
        }
    }

    private var card: some View {
        VStack(spacing: 14 * scale) {
            Image(systemName: symbol).font(.system(size: 40 * scale))
            Text(title).font(.system(size: 30 * scale, weight: .semibold))
            if spec.kind == .resting { countdown(size: 54 * scale) }
            progressText(spec.progress).font(.system(size: 15 * scale)).foregroundStyle(.secondary)
            HStack(spacing: 10) { buttons }
                .controlSize(.large)
                .padding(.top, 6 * scale)
        }
        .padding(28 * scale)
    }

    private var banner: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if spec.kind == .resting { countdown(size: 15) } else { progressText(spec.progress).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) { buttons }.controlSize(.small)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Pieces

    @ViewBuilder private var buttons: some View {
        if spec.kind != .resting {
            Button(primaryTitle) { h.primary() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        if let m = spec.snoozeMinutes { Button("Snooze \(m) min") { h.snooze() } }
        if let m = spec.extendMinutes { Button("+\(m) min") { h.extend() } }
        if spec.canSkip { Button("Skip rest") { h.skip() } }
        Button(closeTitle) { h.hide() }
            .keyboardShortcut(.cancelAction)           // Esc
    }

    private var primaryTitle: LocalizedStringKey {
        spec.kind == .rest ? "Start resting" : "Start working"
    }

    private var closeTitle: LocalizedStringKey {
        if style == .fullScreen { return "Close (Esc)" }
        return spec.kind == .resting ? "Hide" : "Close"
    }

    private var title: LocalizedStringKey {
        switch spec.kind {
        case .rest: return "Rest"
        case .resting: return "Resting"
        case .work: return "Break is over"
        }
    }

    private var symbol: String {
        spec.kind == .work ? "hourglass" : (spec.longBreak ? "bed.double.fill" : "cup.and.saucer.fill")
    }

    private func countdown(size: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = (spec.endsAt ?? context.date).timeIntervalSince(context.date).rounded(.up)
            Text(verbatim: formatClock(Int(left)))
                .font(.system(size: size, weight: .light).monospacedDigit())
        }
    }
}
