# Building BreakBar from source

You only need this to work on the code. To use BreakBar, download it from the
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
