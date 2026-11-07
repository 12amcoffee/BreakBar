import SwiftUI
import BreakBarCore

/// The content of every Rest / Start working window. `style` changes size and layout; the colours come from
/// `BBPalette`: cream (light) or ink (dark) cards, and for the full-screen overlay a tomato screen (light)
/// or an ink screen (dark).
struct PromptView: View {
    @ObservedObject var model: PromptModel
    let style: PromptWindowStyle
    @Environment(\.colorScheme) private var scheme

    private var spec: PromptSpec { model.spec }
    private var h: PromptHandlers { model.handlers }
    private var palette: BBPalette { style == .fullScreen ? .overlay(scheme) : .surface(scheme) }

    var body: some View {
        content.tint(.tomato)
    }

    @ViewBuilder private var content: some View {
        switch style {
        case .banner:
            banner
        case .small:
            windowCard(base: 13.5)
        case .maximised:
            GeometryReader { geo in windowCard(base: min(geo.size.width, geo.size.height) * 0.034) }
        case .fullScreen:
            GeometryReader { geo in fullScreen(base: min(geo.size.width, geo.size.height) * 0.025) }
        }
    }

    // MARK: Small and maximised: a card

    private func windowCard(base: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: base * 1.3, style: .continuous)
        return stack(base: base, titleEm: 2, iconEm: 2.9, clockEm: 3.6, barEm: 16)
            .padding(base * 1.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background, in: shape)
            .overlay { shape.strokeBorder(palette.line, lineWidth: 1) }
    }

    // MARK: Full screen

    private func fullScreen(base: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            palette.background.ignoresSafeArea()
            stack(base: base, titleEm: 3.8, iconEm: 3.2, clockEm: 4.0, barEm: 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button { h.hide() } label: {
                Text("Close (Esc)")
                    .font(.system(size: base * 0.8))
                    .padding(.horizontal, base * 0.7)
                    .padding(.vertical, base * 0.35)
                    .background(palette.control, in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.text)
            .keyboardShortcut(.cancelAction)
            .padding(base * 1.2)
        }
    }

    // MARK: Shared stack

    private func stack(base: CGFloat, titleEm: CGFloat, iconEm: CGFloat, clockEm: CGFloat, barEm: CGFloat) -> some View {
        VStack(spacing: base * 0.9) {
            Image(systemName: symbol)
                .font(.system(size: base * iconEm, weight: .regular))
                .foregroundStyle(palette.icon)
            Text(title)
                .font(.system(size: base * titleEm, weight: .semibold))
            if spec.kind == .resting {
                countdown(size: base * clockEm)
                progressBar(width: base * barEm, height: base * 0.35)
            }
            HStack(spacing: base * 0.7) {
                SessionDots(dots: spec.dots, palette: palette, size: base * 0.7)
                progressText(spec.progress)
            }
            .font(.system(size: base * 0.95))
            .foregroundStyle(palette.secondaryText)
            buttons(base: base)
            if style != .fullScreen && spec.kind != .resting { closeLink(base: base) }
        }
        .foregroundStyle(palette.text)
    }

    private func buttons(base: CGFloat) -> some View {
        // The maximised window scales its text with the screen but keeps its buttons the size of the
        // small window's, so they stay a comfortable size to click.
        let size: CGFloat = style == .maximised ? 13.5 : base
        return VStack(spacing: size * 0.6) {
            if spec.kind != .resting {
                Button(primaryTitle) { h.primary() }
                    .buttonStyle(BBButtonStyle(role: .primary, palette: palette, size: size, fillWidth: true))
                    // Return answers the maximised window. Not the others: a small window or banner that
                    // pops up while you type must not be answered by a stray Return.
                    .returnShortcut(style == .maximised)
            }
            HStack(spacing: size * 0.6) {
                if let m = spec.snoozeMinutes { Button("Snooze \(m) min") { h.snooze() } }
                if let m = spec.extendMinutes { Button("+\(m) min") { h.extend() } }
                if spec.canSkip { Button("Skip rest") { h.skip() } }
                if spec.kind == .resting { hideButton }
            }
            .buttonStyle(BBButtonStyle(role: .secondary, palette: palette, size: size))
            if style == .maximised { keyHint(base: base) }
        }
        .frame(maxWidth: size * 24)
    }

    /// The one-line reminder of which key does what, shown on the maximised window.
    private func keyHint(base: CGFloat) -> some View {
        Group {
            switch spec.kind {
            case .rest: Text("Press Return to start resting")
            case .work: Text("Press Return to start working")
            case .resting: Text("Press Esc to hide")
            }
        }
        .font(.system(size: base * 0.75))
        .foregroundStyle(palette.secondaryText)
    }

    /// While resting, "Hide" is the way out. Esc does the same on the maximised window; the small window
    /// is click-only, and the full-screen overlay has its own Close (Esc) button.
    private var hideButton: some View {
        Button("Hide") { h.hide() }
            .escapeShortcut(style == .maximised)
    }

    private func closeLink(base: CGFloat) -> some View {
        Button { h.hide() } label: { closeLabel }
            .buttonStyle(.plain)
            .font(.system(size: base * 0.85))
            .foregroundStyle(palette.secondaryText)
            .escapeShortcut(style == .maximised)
    }

    /// "Close · Esc" only where Esc really closes the window.
    @ViewBuilder private var closeLabel: some View {
        if style == .maximised {
            Text("Close · Esc")
        } else {
            Text("Close")
        }
    }

    // MARK: Banner

    private var banner: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(palette.icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                bannerSubtitle
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) { bannerButtons }
            Button { h.hide() } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                .buttonStyle(.plain)
                .foregroundStyle(palette.secondaryText)
                .accessibilityLabel("Close")        // the banner is click-only: it never takes the keyboard
        }
        .padding(.horizontal, 14)
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background, in: shape)
        .overlay { shape.strokeBorder(palette.line, lineWidth: 1) }
    }

    @ViewBuilder private var bannerSubtitle: some View {
        if spec.kind == .resting {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("\(clock(at: context.date)) left").monospacedDigit()
            }
        } else {
            progressText(spec.progress)
        }
    }

    @ViewBuilder private var bannerButtons: some View {
        if spec.kind != .resting {
            Button(primaryTitle) { h.primary() }
                .buttonStyle(BBButtonStyle(role: .primary, palette: palette, size: 12))
        }
        if let m = spec.snoozeMinutes {
            Button("Snooze \(m) min") { h.snooze() }
                .buttonStyle(BBButtonStyle(role: .secondary, palette: palette, size: 12))
        }
        if let m = spec.extendMinutes {
            Button("+\(m) min") { h.extend() }
                .buttonStyle(BBButtonStyle(role: .secondary, palette: palette, size: 12))
        }
        if spec.kind == .resting && spec.canSkip {
            Button("Skip rest") { h.skip() }
                .buttonStyle(BBButtonStyle(role: .secondary, palette: palette, size: 12))
        }
    }

    // MARK: Pieces

    private var primaryTitle: LocalizedStringKey {
        spec.kind == .rest ? "Start resting" : "Start working"
    }

    private var title: LocalizedStringKey {
        switch spec.kind {
        case .rest: return "Rest"
        case .resting: return "Resting"
        case .work: return "Break is over"
        }
    }

    private var symbol: String {
        if spec.kind == .work { return "hourglass" }
        return spec.longBreak ? "bed.double" : "cup.and.saucer"
    }

    private func clock(at date: Date) -> String {
        let seconds = (spec.endsAt ?? date).timeIntervalSince(date).rounded(.up)
        return formatClock(Int(seconds))
    }

    private func countdown(size: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(verbatim: clock(at: context.date))
                .font(.system(size: size, weight: .light, design: .monospaced))
                .monospacedDigit()
        }
    }

    private func progressBar(width: CGFloat, height: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let total = max(spec.total ?? 1, 1)
            let left = max(0, (spec.endsAt ?? context.date).timeIntervalSince(context.date))
            let fraction = min(1, max(0.03, 1 - left / total))
            ZStack(alignment: .leading) {
                Capsule().fill(palette.barTrack)
                Capsule().fill(palette.barFill).frame(width: width * fraction)
            }
            .frame(width: width, height: height)
        }
    }
}

private extension View {
    /// Return triggers this button, when `on`.
    @ViewBuilder func returnShortcut(_ on: Bool) -> some View {
        if on {
            self.keyboardShortcut(.defaultAction)
        } else {
            self
        }
    }

    /// Esc triggers this button, when `on`.
    @ViewBuilder func escapeShortcut(_ on: Bool) -> some View {
        if on {
            self.keyboardShortcut(.cancelAction)
        } else {
            self
        }
    }
}
