# 2Ears M0 validation harness

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
