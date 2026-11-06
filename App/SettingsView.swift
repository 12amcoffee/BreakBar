import SwiftUI
import KeyboardShortcuts
import ServiceManagement
import BreakBarCore

/// The Settings window content. Every control edits `controller.settings`, which saves immediately.
struct SettingsView: View {
    @ObservedObject var controller: TimerController
    let effects: EffectsHandler
    let preview: (WindowStyle) -> Void

    var body: some View {
        TabView {
            IntervalsTab(controller: controller)
                .tabItem { Label("Intervals", systemImage: "clock") }
            BreaksTab(controller: controller)
                .tabItem { Label("Breaks", systemImage: "cup.and.saucer") }
            WindowsTab(controller: controller, preview: preview)
                .tabItem { Label("Windows", systemImage: "macwindow") }
            SoundsTab(controller: controller, effects: effects)
                .tabItem { Label("Sounds", systemImage: "speaker.wave.2") }
            GeneralTab(controller: controller)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 460, height: 440)
    }
}

// MARK: - Helpers

extension TimerController {
    /// A binding to one field of the settings. Writing clamps and saves.
    func binding<T>(_ keyPath: WritableKeyPath<TimerSettings, T>) -> Binding<T> {
        Binding(get: { self.settings[keyPath: keyPath] },
                set: { self.settings[keyPath: keyPath] = $0 })
    }
}

/// "Work session ......... 45 min [- +]"
private struct MinutesStepper: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value) min").monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Tabs

private struct IntervalsTab: View {
    @ObservedObject var controller: TimerController

    var body: some View {
        Form {
            Section("Durations") {
                MinutesStepper(title: "Work session", value: controller.binding(\.workMinutes), range: TimerSettings.workRange)
                MinutesStepper(title: "Short rest", value: controller.binding(\.shortRestMinutes), range: TimerSettings.restRange)
                MinutesStepper(title: "Long rest", value: controller.binding(\.longRestMinutes), range: TimerSettings.restRange)
            }
            Section("Long break") {
                Stepper(value: controller.binding(\.sessionsPerSet), in: TimerSettings.setRange) {
                    HStack {
                        Text("Sessions per set")
                        Spacer()
                        Text("\(controller.settings.sessionsPerSet)").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                Toggle("Delay long break by one session", isOn: controller.binding(\.delayLongBreak))
                Text("When a long break is due, take a short one now and the long one after the next work session.")
                    .font(.caption).foregroundStyle(.secondary)
                MinutesStepper(title: "Reset set after", value: controller.binding(\.inactivityResetMinutes), range: 5...1440, step: 5)
            }
        }
        .formStyle(.grouped)
    }
}

private struct BreaksTab: View {
    @ObservedObject var controller: TimerController

    var body: some View {
        let s = controller.settings
        Form {
            Section {
                Toggle("Continuous cycles", isOn: controller.binding(\.continuousCycles))
                Text("Work and rest follow each other with no windows or buttons. Overrides both settings below.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Picker("When work ends", selection: controller.binding(\.whenWorkEnds)) {
                    ForEach(WhenWorkEnds.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("When rest ends", selection: controller.binding(\.whenRestEnds)) {
                    ForEach(WhenRestEnds.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
            .disabled(s.continuousCycles)

            Section("Controls") {
                Toggle("Allow pausing", isOn: controller.binding(\.pauseEnabled))
                Toggle("Allow extending rest", isOn: controller.binding(\.extendEnabled))
                if s.extendEnabled {
                    MinutesStepper(title: "Extend by", value: controller.binding(\.extendMinutes), range: 1...60)
                }
                Toggle("Allow snoozing rest", isOn: controller.binding(\.snoozeEnabled))
                if s.snoozeEnabled {
                    MinutesStepper(title: "Snooze for", value: controller.binding(\.snoozeMinutes), range: 1...60)
                    Stepper(value: controller.binding(\.maxSnoozesPerBreak), in: 1...20) {
                        HStack {
                            Text("Max snoozes per break")
                            Spacer()
                            Text("\(s.maxSnoozesPerBreak)").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct WindowsTab: View {
    @ObservedObject var controller: TimerController
    let preview: (WindowStyle) -> Void

    var body: some View {
        Form {
            Section("Window style") {
                ForEach(WindowStyle.allCases, id: \.self) { style in
                    HStack {
                        Button {
                            controller.settings.windowStyle = style
                        } label: {
                            HStack {
                                Image(systemName: controller.settings.windowStyle == style ? "largecircle.fill.circle" : "circle")
                                Text(style.title)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button("Preview") { preview(style) }
                    }
                }
                Text("Used for both the Rest and Start working windows. Esc or Close always dismisses a window.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct SoundsTab: View {
    @ObservedObject var controller: TimerController
    let effects: EffectsHandler

    var body: some View {
        Form {
            Section {
                row("Windup", \.windupVolume, .windup)
                row("Ding", \.dingVolume, .ding)
                row("Ticking", \.tickingVolume, .ticking)
                Text("Move a slider to hear the sound. Zero turns it off.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Show notifications", isOn: controller.binding(\.notificationsEnabled))
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ title: LocalizedStringKey, _ keyPath: WritableKeyPath<TimerSettings, Double>,
                     _ sound: SoundPlayer.PreviewSound) -> some View {
        HStack {
            Text(title)
            Slider(value: controller.binding(keyPath), in: 0...1, onEditingChanged: { editing in
                if !editing { effects.previewSound(sound) }      // play when the slider is released
            })
            .frame(width: 180)
        }
    }
}

private struct GeneralTab: View {
    @ObservedObject var controller: TimerController
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Show timer in menu bar", isOn: controller.binding(\.showTimerInMenuBar))
            KeyboardShortcuts.Recorder("Start / stop shortcut", name: .startStop)
            KeyboardShortcuts.Recorder("Answer window shortcut", name: .answerPrompt)
            Text("The answer shortcut presses \"Start resting\" or \"Start working\" for you.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        // Registration can fail (e.g. unsigned dev builds); show the real state again.
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Titles for core enums (localised here, not in the core)

extension WhenWorkEnds {
    var title: LocalizedStringKey {
        switch self {
        case .startRestAutomatically: return "Start rest automatically"
        case .showRestWindow: return "Show Rest window"
        }
    }
}

extension WhenRestEnds {
    var title: LocalizedStringKey {
        switch self {
        case .startWorkAutomatically: return "Start working automatically"
        case .showWorkWindow: return "Show Start working window"
        case .stopTimer: return "Stop the timer"
        }
    }
}

extension WindowStyle {
    var title: LocalizedStringKey {
        switch self {
        case .small: return "Small floating window"
        case .maximised: return "Maximised floating window"
        case .fullScreen: return "Full-screen overlay"
        case .banner: return "Notification-style banner"
        }
    }
}
