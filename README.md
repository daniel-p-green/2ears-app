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
(Listening Score with its breakdown, share against target, sparkline per minute, longest
stretch, nudges and whether you course-corrected), History (30-day retention, swipe to delete).

The Listening Score is a 0 to 100 rating in the Sleep Score idiom, computed in `TwoEarsCore`
(`ListeningScore`) from the summary alone: 60 points for staying at or under your target
share, fading to zero 35 points past it; 20 points for keeping your longest uninterrupted
stretch under a minute, fading to zero at three minutes; 20 points for course-correcting
after nudges, with full credit when no nudge was needed. Bands: Excellent 90+, Good 75+,
OK 60+, Low 40+, Very Low below. Presenting sessions and sessions without a share estimate
are not scored. Colors are system colors throughout: cyan accent, deep blue navigation glow,
orange only when over the threshold, and Sleep's green, yellow, orange, and red for bands.

The simulator has no microphone, so on the simulator the app plays a scripted four-minute
conversation through the real classifier. On a device it uses the wrist microphone, suspends
for phone calls and resumes after, warns on the controls page at 20% battery, and ends the
session at 5%. "Start listening with two.ears" is a Siri phrase (App Intent) that opens a
Listen session.

The nudge state machine (`NudgeController`) and the summary aggregates (`SessionAggregator`)
live in `TwoEarsCore` and are covered by `swift test`; the watch target only wires them to
audio, haptics, and SwiftUI. The watch target builds in Swift 6 language mode.

**Complication.** The `TwoEarsComplication` WidgetKit extension (embedded in the app) offers a
Start Listening complication in the circular, corner, rectangular, and inline families. Tapping it
opens the app through the `twoears://start` URL scheme straight into a Listen session. Verified on
the watchOS 27 simulator on the Activity Analog face. Note that `xcrun simctl openurl` cannot
exercise this path on watchOS; add the complication to a face and tap it.

**Launch video.** `videos/two-ears-launch/` is a HyperFrames project: `BRIEF.md`, `STORYBOARD.md`,
`SCRIPT.md`, seven frame compositions, staged fonts, and local Kokoro narration. Render with
`npx hyperframes render --quality high --output renders/video.mp4` from that folder (renders are
gitignored). The delivered cut is 39 seconds, 1080x1080, narrated and captioned, with no music
because no music provider was signed in; `npx hyperframes auth login` and a re-run of the audio
step add a HeyGen bed and voice.

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
