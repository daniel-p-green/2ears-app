# two.ears

A private talk-share coach for Apple Watch. It measures how much of a conversation you are
talking, from loudness alone, and taps your wrist when you cross the share you chose.
No audio is stored, transcribed, or sent anywhere.

This repo holds three things:

- `Sources/TwoEarsCore`: the classifier (level, noise floor, VAD, attribution, talk share).
  Pure Swift, no file or network APIs. Shared by the watch app and the lab harness.
- `Watch/`: the watchOS app (`Watch/TwoEars.xcodeproj`, target `TwoEarsWatch`, display name two.ears).
- `Sources/TwoEarsLab*`: `twoears-lab`, the M0 validation harness described below.

## Watch app

Open `Watch/TwoEars.xcodeproj` and run `TwoEarsWatch` on a watch simulator or device.
From the command line:

    xcodebuild -project Watch/TwoEars.xcodeproj -scheme TwoEarsWatch \
      -destination 'platform=watchOS Simulator,name=Apple Watch Series 12 (42mm)' build

Screens: Start (intent picker, history, streak), Live (a single ring showing your share of
the trailing two minutes, orange once you cross the threshold, elapsed time, End), Summary
(share against target, sparkline per minute, longest stretch, nudges and whether you
course-corrected), History (30-day retention, swipe to delete).

The simulator has no microphone, so on the simulator the app plays a scripted four-minute
conversation through the real classifier. On a device it uses the wrist microphone, suspends
for phone calls and resumes after, warns on the controls page at 20% battery, and ends the
session at 5%. "Start listening with two.ears" is a Siri phrase (App Intent) that opens a
Listen session.

The nudge state machine (`NudgeController`) and the summary aggregates (`SessionAggregator`)
live in `TwoEarsCore` and are covered by `swift test`; the watch target only wires them to
audio, haptics, and SwiftUI. The watch target builds in Swift 6 language mode.

The extended-runtime session type is `mindfulness` in `Watch/TwoEarsWatch-Info.plist`: it is
the only frontmost type with a one-hour limit (self-care is ten minutes). The app renews the
session when it expires or when you return after leaving the app, so longer conversations
keep going as long as you come back to the app; the session clock is pipeline time, so time
away or on a call never reads as silence. Whether App Review accepts `mindfulness` for a
listening coach is still the open question from the spec. There is no complication yet.

First things to test on a physical watch: that the microphone keeps delivering with the wrist
down for the whole runtime window, and that haptics fire with the screen off.

## M0 validation harness

`twoears-lab` records scripted, labeled conversation samples on a Mac and grades the
2Ears loudness classifier against the spec's 85% attribution-accuracy gate.

**This harness stores audio on disk. The 2Ears product never does.** The harness exists
so recordings can be re-analyzed while thresholds are tuned. Nothing in `Sources/TwoEarsCore`
touches a file; that library is the part that ships on the watch.

## Build

    swift build
    swift test

## Usage

    swift run twoears-lab devices
    swift run twoears-lab record --condition quiet --device "iPhone Microphone" --notes "iPhone at left wrist, partner 1.5 m"
    swift run twoears-lab analyze sessions/<dir> [--sweep] [--dump-windows windows.csv]
    swift run twoears-lab report sessions/ --out report.md

Recording sessions land in `sessions/` (gitignored). See
`docs/superpowers/specs/2026-09-15-m0-validation-harness-design.md` for the design.
