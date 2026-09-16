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
conversation through the real classifier. On a device it uses the wrist microphone.

Unresolved from the spec and still open here: the extended-runtime session type is
`self-care` in `Watch/TwoEarsWatch-Info.plist` pending App Review guidance, and there is no
complication or Siri intent yet.

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
