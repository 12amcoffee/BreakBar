# Developing BreakBar

This page is for working on the code. To use BreakBar, download it from the
[Releases page](https://github.com/12amcoffee/BreakBar/releases/latest) or install it with Homebrew
(see the [README](README.md)); neither needs Xcode.

## What you need

- macOS 13 (Ventura) or later
- Xcode 15 or later (free from the App Store)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build and run

```bash
xcodegen                      # creates BreakBar.xcodeproj from project.yml
open BreakBar.xcodeproj       # then press ⌘R
```

The app is signed "to run locally", so no Apple developer account is needed. **Launch at login** may
refuse to switch on for such a build; it works for a properly signed one.

## Tests

Unit tests for all timer logic (no UI, runs on macOS and Linux):

```bash
swift test --package-path Core
```

Translations check (English, 简体中文, 日本語 must have identical keys):

```bash
python3 scripts/check-strings.py
```

## Releases

Releases are built by GitHub Actions (`.github/workflows/release.yml`) when a tag such as `v2.0.0` is
pushed, never on a personal machine. The workflow builds a universal app, packs the DMG and zip, and
generates the Homebrew cask file.

## Project layout

```
Core/       Swift package, no UI: settings, state machine, formatting, URL commands, tests
App/        the macOS app: menu bar, dropdown, Settings, windows, sounds, notifications, hotkeys
  Prompt/     the Rest / Start working windows (4 styles)
  *.lproj     English, Chinese (Simplified), Japanese strings
Design/     logo, download button, masters and editable SVG sources (tomato #E5432B, cream #FFF9F2)
docs/       the interactive preview page and the images used in this README
packaging/  Homebrew cask template, installer layout
scripts/    make-sounds.py (synthesises the sounds), check-strings.py
```


The state machine is one pure function-like struct (`Core/.../TimerMachine.swift`): you give it an
event and the current time, it changes state and returns effects (sound, notification). It never
touches the screen, which is why it is fully unit-tested. The app turns state into windows.

## State machine

| State | Meaning | Menu bar |
|---|---|---|
| `idle` | nothing running | icon only |
| `working(endsAt)` | work countdown | hourglass, `32:10` |
| `awaitingRest(kind, since, snoozes)` | work done, Rest window waiting for **Start resting** | bell, `+01:23` (counts up) |
| `snoozed(kind, until, snoozes)` | Snooze pressed, window returns at `until` | zzz, `01:45` |
| `resting(kind, endsAt)` | short or long rest countdown | cup / bed, `08:12` |
| `awaitingWork(kind, since)` | rest done, Start working window waiting | bell badge, `+00:34` |
| `paused(phase, remaining, since)` | work or rest paused | pause, `44:00` |

| From | Event | To | Notes |
|---|---|---|---|
| idle | start | working | inactivity rule may reset the set first |
| working | timer ends | resting **or** awaitingRest | set counter +1; "When work ends" decides |
| working | timer ends > 60 s late | idle | the Mac slept; session not counted |
| awaitingRest | startRest | resting | rest timer starts at the click |
| awaitingRest | snooze | snoozed | only if snoozes < limit |
| snoozed | time passes | awaitingRest | window comes back |
| awaitingRest / snoozed | skip | working | counter unchanged |
| resting | extend | resting | end time + increment |
| resting | skip | working | counter unchanged |
| resting | timer ends | working / awaitingWork / idle | "When rest ends" decides |
| awaitingWork | startWork | working | |
| awaitingWork | extend | resting | a fresh rest of the increment length |
| awaitingWork | skip | working | same as startWork |
| working / resting | pause | paused | working also stops the ticking sound |
| paused | resume | working / resting | remaining time kept |
| any non-idle | stop | idle | counter kept (see "Long break counter" in the README) |
| awaitingRest / awaitingWork / snoozed / paused | nothing for longer than the inactivity limit | idle | set reset |

**Continuous cycles** forces both "When work ends" and "When rest ends" to *automatic*, so the
prompts never appear.

## Manual test checklist

1. App appears in the menu bar with no Dock icon; the dropdown opens; Quit works.
2. Click a pill, then its number: it becomes a text box; type a value and press Return. Nothing is selected until you click.
3. Settings: set work to 1 min; Start; at zero the Rest window appears and the menu bar shows `+00:xx`.
4. **Start resting** starts the rest only then. Snooze 2 min hides it and it comes back.
5. Each style: Preview, then live. Check over a full-screen app and on another Space.
6. Maximised window: Return starts the rest, Esc hides it and your previous app comes back. Full-screen overlay: Esc and Close (Esc) both dismiss (with two displays both dim). Small window and banner: the Close / × button.
7. Sounds: move the Ding slider (plays on release); work end plays it.
8. Notification appears with Skip when "When work ends" is automatic.
9. Hotkeys work from another app. `open breakbar://toggle` works in Terminal.
10. Quit and relaunch: settings and "Session x of N" are kept.
