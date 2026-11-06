# BreakBar

A macOS menu bar Pomodoro timer with fully custom intervals (I use 45 / 10) and a
**Rest window**: when work ends, a window says "Rest" and the rest timer only starts when you
click **Start resting**.

Inspired by [TomatoBar](https://github.com/ivoronin/TomatoBar) by Ilya Voronin (MIT). BreakBar is a
fresh rewrite; no TomatoBar code, sounds or icons are used.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later (free from the App Store)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build, run, test

```bash
xcodegen                      # creates BreakBar.xcodeproj from project.yml
open BreakBar.xcodeproj       # then press ⌘R
```

Unit tests for all timer logic (no UI, runs on macOS and Linux):

```bash
swift test --package-path Core
```

Translations check (English, 简体中文, 日本語 must have identical keys):

```bash
python3 scripts/check-strings.py
```

The app is signed "to run locally" so no Apple developer account is needed. **Launch at login** may
refuse to switch on for such a build; it works for a properly signed one.

## Project layout

```
Core/    Swift package, no UI: settings, state machine, formatting, URL commands, tests
App/     the macOS app: menu bar, popover, Settings, windows, sounds, notifications, hotkeys
  Prompt/  the Rest / Start working windows (4 styles)
  *.lproj  English, Chinese (Simplified), Japanese strings
  Assets.xcassets  app icon, menu bar glyph (template image), accent colour
Design/  logo masters and editable SVG sources (tomato #E5432B, cream #FFF4E6)
scripts/ make-sounds.py (synthesises the sounds), check-strings.py
project.yml  XcodeGen spec
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
| any non-idle | stop | idle | counter kept (see below) |
| awaitingRest / awaitingWork / snoozed / paused | nothing for longer than the inactivity limit | idle | set reset |

**Continuous cycles** forces both "When work ends" and "When rest ends" to *automatic*, so the
prompts never appear.

## Long break counter

- Counts completed work sessions in the current set. A session counts the moment its timer reaches zero.
- Shown as "Session 2 of 4" while working and "2 of 4 done" while resting.
- **Resets** when a long break *starts* (also if you then skip it), on **Reset set** in the popover,
  and after **inactivity** (default 60 min, configurable): nothing running, or a window left
  unanswered, for longer than that starts a fresh set.
- **Stop does not reset it**, unlike TomatoBar: stepping away mid-session should not wipe progress.
- **Delay long break**: when a long break is due, you get a short one now and the long one after
  the next work session. It delays once, so you can't postpone forever.
- The counter survives quitting the app.

## Skip, extend, snooze: edge cases

- **Skip** never changes the counter. Skipping a long break still resets the set.
- **Extend** never changes the counter. Repeated extends are allowed; each adds the increment.
  From the Start working window, "+N min" goes back into a rest.
- **Snooze** never changes the counter (the session already counted) and snooze time is neither work
  nor rest. **Repeated snoozing is capped** (default 3 per break); after that only Start resting and
  Skip are offered. A window left snoozed or unanswered longer than the inactivity limit ends the
  run (idle, set reset) so you don't return hours later to a stale prompt.
- **Closing a window** (Close / Hide / Esc) never changes the timer. The menu bar keeps showing the
  waiting state and the popover still has the Start button.
- **Sleep**: a work or rest that ends more than 60 s late (lid closed) goes to idle without counting.

## Windows

All four styles float above other apps, follow you across Spaces and appear over full-screen apps.
Esc and a Close button always work. *Preview* buttons in Settings > Windows show each style with
sample data (a preview closes itself after 12 s and never touches the timer).

| Style | Behaviour |
|---|---|
| Small floating window | centred card; does not steal keyboard focus (click it, or use the answer hotkey) |
| Maximised floating window | nearly full screen; menu bar and Dock stay visible |
| Full-screen overlay | dims every display; "Close (Esc)" button; takes focus so Esc works |
| Notification-style banner | slides in at top right; own window, not a system notification |

After **Start resting** the window becomes a countdown with +N min, Skip rest and Hide.
System notifications are only sent when no window says the same thing (e.g. automatic rest).

## Integrations

- **URLs**: `open breakbar://start` · `stop` · `toggle` · `startRest` · `startWork` · `snooze` · `skip` · `extend` · `pause` · `resume` · `resetSet`
- **Shortcuts app**: actions Start timer, Stop timer, Start resting, Start working, Skip rest.
  Apps cannot switch Do Not Disturb / Focus themselves; in Shortcuts, combine "Set Focus" with
  "Start timer" to get that.
- **Hotkeys** (Settings > General): start/stop, and "answer window" (presses Start resting / Start working).
- **Event log**: one JSON line per state change in `Application Support/BreakBar/events.jsonl`
  inside the app's sandbox container (`~/Library/Containers/com.fnm945.BreakBar/Data/Library/Application Support/BreakBar/`).

## Manual test checklist (things unit tests can't see)

1. App appears in the menu bar with no Dock icon; popover opens; Quit works.
2. Settings: set work to 1 min; Start; at zero the Rest window appears and the menu bar shows `+00:xx`.
3. **Start resting** starts the rest only then. Snooze 2 min hides it and it comes back.
4. Each style: Preview, then live. Check over a full-screen app and on another Space.
5. Full-screen overlay: Esc and the Close button both dismiss; with two displays both dim.
6. Sounds: move the Ding slider (plays on release); work end plays it.
7. Notification appears with Skip when "When work ends" is automatic.
8. Hotkeys work from another app. `open breakbar://toggle` works in Terminal.
9. Quit and relaunch: settings and "Session x of N" are kept.

## Feature checklist

| Feature | TomatoBar | BreakBar |
|---|---|---|
| Menu bar icon per state | ✅ | ✅ |
| Countdown in menu bar (toggle) | ✅ | ✅ |
| Popover Start/Stop, "Stop" on hover | ✅ | ✅ |
| Custom work / short / long durations | 1–60 | 1–180 |
| Sessions per set before long break | 1–10 | 1–12 |
| Stop after break | ✅ | ✅ ("When rest ends: Stop the timer") |
| Sounds with volume | windup / ding / ticking | same three, own recordings, quiet by default |
| Notifications, Skip action | ✅ | ✅ |
| Global hotkey | ✅ | ✅ + second "answer window" hotkey |
| Launch at login | ✅ | ✅ |
| Settings persisted | ✅ | ✅ (+ session counter) |
| Late tick after sleep protection | ✅ | ✅ |
| JSON event log | ✅ | ✅ |
| URL scheme | `startStop` | 11 commands |
| Languages | en, ko, zh-Hans | en, zh-Hans, ja |
| **Rest window (Flow-style)** | – | ✅ 4 styles, previews |
| **Start working window** | – | ✅ same style, independent setting |
| Long break every N sessions + progress | partly | ✅ shown in menu and windows |
| Configurable counter reset | – | ✅ manual, inactivity, on long break |
| Delay long break | – | ✅ |
| Skip / extend / snooze | skip only (notification) | ✅ all three, toggles |
| Pause (toggle) | – | ✅ |
| Continuous cycles (toggle) | (default) | ✅ |
| Shortcuts actions | – | ✅ |

## Credits

- Idea and feature set inspired by [TomatoBar](https://github.com/ivoronin/TomatoBar) (MIT, © Ilya Voronin) and the Flow app's Rest window.
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus (MIT) for the hotkey recorder.
- Sounds are synthesised by `scripts/make-sounds.py`.
