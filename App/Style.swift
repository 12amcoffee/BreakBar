import SwiftUI
import BreakBarCore

/// BreakBar's own buttons: a flat tomato fill (cream label) for the main action and a quiet fill for the rest.
/// Everything scales from `size`, the font size in points, so the same style serves the 13 pt popover and
/// the large full-screen overlay.
struct BBButtonStyle: ButtonStyle {
    enum Role { case primary, secondary }

    var role: Role = .primary
    var palette: BBPalette
    var size: CGFloat = 13
    var fillWidth = false

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        BBButtonBody(configuration: configuration, role: role, palette: palette, size: size, fillWidth: fillWidth)
    }
}

private struct BBButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let role: BBButtonStyle.Role
    let palette: BBPalette
    let size: CGFloat
    let fillWidth: Bool
    @State private var hovering = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: size * 0.6, style: .continuous) }
    private var highlighted: Bool { configuration.isPressed || hovering }

    var body: some View {
        configuration.label
            .font(.system(size: size, weight: role == .primary ? .semibold : .medium))
            .foregroundStyle(role == .primary ? palette.primaryLabel : palette.text)
            .padding(.horizontal, size * 1.1)
            .frame(maxWidth: fillWidth ? .infinity : nil, minHeight: size * (role == .primary ? 2.6 : 2.3))
            .background(fill, in: shape)
            .overlay { if role == .secondary, let outline = palette.outline { shape.strokeBorder(outline, lineWidth: max(1, size * 0.08)) } }
            .contentShape(shape)
            .onHover { hovering = $0 }
    }

    private var fill: Color {
        switch role {
        case .primary:
            return highlighted ? palette.primaryPressed : palette.primaryFill
        case .secondary:
            if palette.outline != nil { return highlighted ? palette.hover : .clear }
            return highlighted ? palette.hover : palette.control
        }
    }
}

/// "Session 2 of 4" as dots: filled for finished sessions, a ring for the one in progress.
struct SessionDots: View {
    let dots: DotProgress
    let palette: BBPalette
    var size: CGFloat = 9

    var body: some View {
        HStack(spacing: size * 0.65) {
            ForEach(0..<max(dots.total, 0), id: \.self) { index in
                dot(index)
            }
        }
        .accessibilityHidden(true)       // the text next to the dots says the same thing
    }

    @ViewBuilder private func dot(_ index: Int) -> some View {
        if index < dots.done {
            Circle().fill(palette.dotDone).frame(width: size, height: size)
        } else if dots.hasCurrent && index == dots.done {
            Circle().strokeBorder(palette.dotDone, lineWidth: size * 0.22).frame(width: size, height: size)
        } else {
            Circle().fill(palette.dotOff).frame(width: size, height: size)
        }
    }
}

/// A number that looks like plain text. Hover to see it is editable (a box appears); click to type a value,
/// then Return or click away to apply it, Esc to cancel. Only digits are accepted and the value is clamped
/// to `range`. Nothing is focused until you click, so opening a window never lands the cursor here.
struct NumberField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat = 46
    var fill: Color = Color.primary.opacity(0.08)
    /// Told when typing starts and stops, so a window can keep Return away from its default button meanwhile.
    var onEditing: ((Bool) -> Void)? = nil

    @State private var editing = false
    @State private var hovering = false
    @State private var text = ""
    @FocusState private var focused: Bool

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 6, style: .continuous) }

    var body: some View {
        ZStack(alignment: .trailing) {
            if editing {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($focused)
                    .onAppear {
                        focused = true
                        // Select the old number, so typing replaces it (the usual Mac behaviour on click).
                        DispatchQueue.main.async {
                            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                        }
                    }
                    .onChange(of: text) { newText in
                        let digits = String(newText.filter { $0.isASCII && $0.isNumber }.prefix(4))
                        if digits != newText { text = digits }
                    }
                    .onChange(of: focused) { isFocused in
                        if !isFocused { finish(apply: true) }          // clicked away
                    }
                    .onSubmit { finish(apply: true) }
                    .onExitCommand { finish(apply: false) }            // Esc cancels
            } else {
                Text(verbatim: String(value)).monospacedDigit()
            }
        }
        .frame(width: width, alignment: .trailing)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(hovering || editing ? fill : Color.clear, in: shape)
        .overlay { shape.strokeBorder(Color.tomato, lineWidth: editing ? 1.5 : 0) }
        .contentShape(shape)
        .onHover { hovering = $0 }
        .onTapGesture { beginEditing() }
        .onDisappear { if editing { onEditing?(false) } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func beginEditing() {
        guard !editing else { return }
        text = String(value)
        editing = true
        onEditing?(true)
    }

    private func finish(apply: Bool) {
        guard editing else { return }
        if apply, let typed = Int(text) {
            let clamped = min(range.upperBound, max(range.lowerBound, typed))
            if clamped != value { value = clamped }
        }                                                              // empty or unreadable: keep the old value
        editing = false
        onEditing?(false)
    }
}
