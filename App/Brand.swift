import SwiftUI
import AppKit

/// The BreakBar palette (from the logo).
extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    static let tomato = Color(hex: 0xE5432B)
    static let tomatoPress = Color(hex: 0xCC3A24)
    static let cream = Color(hex: 0xFFF9F2)
    static let ink = Color(hex: 0x1F1A17)
    static let restPink = Color(hex: 0xFFC9BB)
    static let coral = Color(hex: 0xFF8C6F)        // selected pill and rest progress bar in dark mode

    /// Warm window background: cream in light mode, ink in dark mode.
    static let surface = Color(nsColor: .bbSurface)
}

extension NSColor {
    /// A colour that switches between a light-mode and a dark-mode value with the system appearance.
    static func adaptive(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    static let bbSurface = adaptive(
        light: NSColor(srgbRed: 1.0, green: 0.976, blue: 0.949, alpha: 1),        // cream #FFF9F2
        dark: NSColor(srgbRed: 0.122, green: 0.102, blue: 0.090, alpha: 1))       // ink   #1F1A17
}

/// Every colour a BreakBar surface needs, chosen once per look so views never pick colours ad hoc.
/// `surface` is the popover and the small, maximised and banner windows. `overlay` is the full-screen
/// overlay: a tomato screen in light mode, an ink screen in dark mode.
struct BBPalette {
    var background: Color
    var text: Color
    var secondaryText: Color
    var line: Color
    var control: Color          // quiet button / track fill
    var hover: Color            // hover and selected-row highlight
    var primaryFill: Color
    var primaryPressed: Color
    var primaryLabel: Color
    var dotDone: Color
    var dotOff: Color
    var icon: Color
    var barTrack: Color
    var barFill: Color
    var outline: Color? = nil   // secondary buttons are outlined instead of filled when set
    var selectedFill: Color = .restPink     // the selected interval pill
    var selectedLabel: Color = .ink
    var selectedRing: Color? = .tomato      // nil: no ring (dark mode)

    static func surface(_ scheme: ColorScheme) -> BBPalette {
        if scheme == .dark {
            return BBPalette(
                background: .ink, text: Color(hex: 0xF3EDE7), secondaryText: Color(hex: 0xF3EDE7, opacity: 0.62),
                line: Color(hex: 0xFFF9F2, opacity: 0.14), control: Color(hex: 0xFFF9F2, opacity: 0.12),
                hover: Color(hex: 0xE5432B, opacity: 0.26),
                primaryFill: .tomato, primaryPressed: .tomatoPress, primaryLabel: .cream,
                dotDone: .tomato, dotOff: Color(hex: 0xFFF9F2, opacity: 0.22), icon: .tomato,
                barTrack: Color(hex: 0xFFF9F2, opacity: 0.12), barFill: .coral,
                selectedFill: .coral, selectedLabel: .ink, selectedRing: nil)
        }
        return BBPalette(
            background: .cream, text: .ink, secondaryText: Color(hex: 0x1F1A17, opacity: 0.62),
            line: Color(hex: 0x1F1A17, opacity: 0.13), control: Color(hex: 0x1F1A17, opacity: 0.08),
            hover: Color(hex: 0xFFC9BB, opacity: 0.6),
            primaryFill: .tomato, primaryPressed: .tomatoPress, primaryLabel: .cream,
            dotDone: .tomato, dotOff: Color(hex: 0x1F1A17, opacity: 0.2), icon: .tomato,
            barTrack: Color(hex: 0x1F1A17, opacity: 0.08), barFill: .restPink)
    }

    static func overlay(_ scheme: ColorScheme) -> BBPalette {
        if scheme == .dark {                                   // B: ink screen, tomato button
            return BBPalette(
                background: .ink, text: .cream, secondaryText: Color(hex: 0xF3EDE7, opacity: 0.7),
                line: Color(hex: 0xFFF9F2, opacity: 0.2), control: Color(hex: 0xFFF9F2, opacity: 0.12),
                hover: Color(hex: 0xE5432B, opacity: 0.3),
                primaryFill: .tomato, primaryPressed: .tomatoPress, primaryLabel: .cream,
                dotDone: .tomato, dotOff: Color(hex: 0xFFF9F2, opacity: 0.22), icon: .tomato,
                barTrack: Color(hex: 0xFFF9F2, opacity: 0.28), barFill: .coral,
                outline: Color(hex: 0xFFF9F2, opacity: 0.5))
        }
        return BBPalette(                                      // A: tomato screen, cream button
            background: .tomato, text: .cream, secondaryText: .cream,
            line: Color(hex: 0xFFF9F2, opacity: 0.3), control: Color(hex: 0xFFF9F2, opacity: 0.16),
            hover: Color(hex: 0xFFC9BB, opacity: 0.28),
            primaryFill: .cream, primaryPressed: .white, primaryLabel: .ink,
            dotDone: .cream, dotOff: Color(hex: 0xFFF9F2, opacity: 0.4), icon: .cream,
            barTrack: Color(hex: 0xFFF9F2, opacity: 0.28), barFill: .restPink,
            outline: Color(hex: 0xFFF9F2, opacity: 0.5))
    }
}
