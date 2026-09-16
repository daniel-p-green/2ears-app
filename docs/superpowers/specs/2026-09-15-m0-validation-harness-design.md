# M0 validation harness design

Date: 2026-09-15
Status: approved design, pre-implementation
Source spec: "2Ears product spec v0.2" (September 2026), milestone M0

## Purpose

M0 answers one question: does a wrist-distance microphone plus a fixed-threshold loudness classifier separate "wearer speaking" from "room speaking" well enough to build 2Ears on? The spec sets the gate: window-level attribution accuracy at or above 85% in a quiet room with fixed thresholds, plus documented failure modes in cafe noise. The output of M0 is a go/no-go on the wrist-only architecture.

The harness is a lab tool, not the product. It stores audio on disk so results can be re-analyzed. The product never stores audio. The README states this distinction in its first paragraph.

## Decisions made during brainstorming

- Capture runs on the Mac through any Core Audio input device: built-in mic, wired lav, or an iPhone via Continuity held at wrist distance. A watch recorder app is out of scope; the analyzer accepts any 16 kHz mono WAV so watch captures can be added later without changes.
- Ground truth comes from scripted turns. The harness shows timed prompts (YOU, PARTNER, BOTH, SILENCE) and derives labels from the block timeline. No live keypress labeling and no reference microphones.
- One Swift package holds both the classifier library and the CLI. The library contains no AVFoundation dependency, so it moves into the watchOS app unchanged in M1.

## Package layout

```
2ears-app/
  Package.swift                 swift-tools 6.0, macOS 14+
  Sources/
    TwoEarsCore/                library, pure Swift, no platform audio imports
      ClassifierConfig.swift    every tunable constant with the spec defaults
      WindowStat.swift          per-window record
      LevelMeter.swift          RMS to dBFS for a 100 ms sample block
      NoiseFloorTracker.swift   slow-adapting 10th percentile over trailing 10 s
      VadClassifier.swift       voiced/unvoiced with ZCR band and burst rejection
      AttributionClassifier.swift  user / room / uncertain from loudness bands
      TalkShareEstimator.swift  trailing 120 s share with minimum-evidence gate
      Pipeline.swift            runs samples through the stages, yields WindowStat
    TwoEarsLabKit/              library with all lab logic, testable without a process spawn
      AudioCapture.swift        AVAudioEngine input, converts to 16 kHz mono Float32
      TurnScript.swift          script model and default script
      SessionFiles.swift        paths and JSON codecs
      Scorer.swift              label alignment and metrics
      Analyzer.swift            runs Pipeline over a WAV, scores, sweeps
      Reporter.swift            aggregates analyses into report.md
    TwoEarsLab/                 thin executable `twoears-lab`
      Lab.swift                 ArgumentParser root command
      RecordCommand.swift       prompts and session writing on top of AudioCapture
      AnalyzeCommand.swift      argument parsing, calls Analyzer
      ReportCommand.swift       argument parsing, calls Reporter
  Tests/
    TwoEarsCoreTests/           synthetic-signal tests per stage
    TwoEarsLabKitTests/         scorer and end-to-end fixture tests
  Scripts/
    default.json                the standard turn script
  docs/superpowers/specs/       this document
  README.md
```

Dependencies: `swift-argument-parser` only. AVFoundation is used from `TwoEarsLabKit` for capture and WAV I/O. `TwoEarsLab` contains no logic beyond argument parsing so every behavior is covered by library tests.

## Classifier library (TwoEarsCore)

All constants live in `ClassifierConfig` with these defaults from the spec:

| Constant | Default | Meaning |
| --- | --- | --- |
| sampleRate | 16000 | Hz, mono Float32 |
| windowMs | 100 | analysis window |
| floorTrailingSec | 10 | noise-floor history length |
| floorPercentile | 0.10 | 10th percentile of window levels |
| vadMarginDb | 8 | level must exceed floor by this to be voiced |
| zcrMin, zcrMax | 0.01, 0.20 | zero crossings per sample accepted as speech |
| minBurstMs | 800 | voiced runs shorter than this are dropped |
| userBandDb | 16 | level above floor plus this is the wearer |
| uncertainMarginDb | 3 | windows within this of the user boundary are uncertain |
| shareWindowSec | 120 | trailing window for talk share |
| minVoicedSec | 15 | below this total voiced time, share is uncertain |
| maxUncertainFraction | 0.30 | above this, share is uncertain |

Stage behavior:

1. **LevelMeter** computes RMS over the window and converts to dBFS. Silence (all zeros) maps to a floor of -120 dBFS rather than negative infinity.
2. **NoiseFloorTracker** keeps a ring buffer of the last 100 window levels and reports the 10th percentile using the nearest-rank method: sort ascending and take the element at index `floor(0.10 * count)`. No interpolation. Before the buffer has 20 windows it reports the minimum seen so far.
3. **VadClassifier** marks a window voiced when level exceeds floor plus vadMarginDb and the window's zero-crossing rate lies within [zcrMin, zcrMax]. It then applies burst rejection: a run of voiced windows shorter than minBurstMs is relabeled unvoiced. Burst rejection introduces a lag of minBurstMs because a run cannot be confirmed until it reaches that length; the pipeline emits windows with that delay and the scorer accounts for it by aligning on window index, not arrival time.
4. **AttributionClassifier** assigns each voiced window: `user` if level is at or above floor plus userBandDb plus uncertainMarginDb; `uncertain` if within plus or minus uncertainMarginDb of floor plus userBandDb; otherwise `room`. Unvoiced windows carry no attribution.
5. **TalkShareEstimator** holds the trailing 1200 windows and returns either a share value (user voiced seconds over total voiced seconds) or `.uncertain` when total voiced time is under minVoicedSec or the uncertain fraction exceeds maxUncertainFraction.

`WindowStat` fields: `index`, `startMs`, `levelDb`, `noiseFloorDb`, `zcr`, `voiced`, `attribution` (user, room, uncertain, or nil when unvoiced).

`Pipeline` is a stateful object that accepts sample chunks of any length, buffers to whole windows, and returns the `WindowStat` values completed by that chunk. Because burst rejection holds up to eight windows until a voiced run is confirmed, `Pipeline` also has a `finish()` method that resolves any pending run as unvoiced, emits the held windows, and discards any partial window. Callers must call it at end of stream or on Ctrl-C so no windows go unscored. `Pipeline` exposes `currentShare`, the `TalkShareEstimator` output as of the last emitted window, so both the analyzer and the future watch app read share from the same place. `Pipeline` is the only entry point the watch app will need.

## Record command

```
twoears-lab record --condition quiet|cafe|other --device "<name>" [--script path] [--notes "text"] [--out sessions/]
twoears-lab devices
```

- `devices` lists Core Audio input devices by name and exits.
- `record` opens the named device with AVAudioEngine, installs an input tap, converts the hardware format to 16 kHz mono Float32 with AVAudioConverter, and writes `audio.wav` with AVAudioFile. Recording starts after a 3-second visual countdown and stops when the script ends or on Ctrl-C, in which case the labels file records the truncated end time.
- Prompts render in the terminal as a large label (YOU / PARTNER / BOTH / SILENCE), the block's remaining seconds, and the next block's label. No audio cues are played; a cue would pollute the recording.
- Output directory: `sessions/<yyyyMMdd-HHmmss>-<condition>/` containing `audio.wav` and `labels.json`.

`labels.json`:

```json
{
  "version": 1,
  "recordedAt": "2026-09-15T18:20:00Z",
  "condition": "quiet",
  "device": "iPhone Microphone",
  "notes": "watch position, iPhone at left wrist, partner 1.5 m",
  "sampleRate": 16000,
  "scriptName": "default",
  "blocks": [
    { "label": "silence", "startMs": 0, "endMs": 5000 },
    { "label": "you", "startMs": 5000, "endMs": 25000 }
  ],
  "endedEarlyAtMs": null
}
```

Turn script format (`Scripts/default.json`):

```json
{
  "name": "default",
  "blocks": [
    { "label": "silence", "seconds": 5 },
    { "label": "you", "seconds": 20 },
    { "label": "partner", "seconds": 20 },
    { "label": "you", "seconds": 20 },
    { "label": "partner", "seconds": 20 },
    { "label": "silence", "seconds": 5 },
    { "label": "both", "seconds": 10 },
    { "label": "partner", "seconds": 20 },
    { "label": "you", "seconds": 20 },
    { "label": "silence", "seconds": 5 },
    { "label": "partner", "seconds": 20 },
    { "label": "you", "seconds": 20 },
    { "label": "silence", "seconds": 5 }
  ]
}
```

Total default duration: 190 seconds.

## Analyze command

```
twoears-lab analyze <session-dir> [--config overrides.json] [--sweep] [--dump-windows windows.csv]
```

Reads `audio.wav` and `labels.json`, runs `Pipeline`, and scores. Writes `analysis.json` beside the inputs and prints a summary.

Scoring rules:

- Each window's truth label is the block containing its start time. Windows whose start lies within 500 ms of any block boundary are marked `margin` and excluded from every metric.
- Windows in `both` blocks are excluded from attribution accuracy and VAD metrics. They are reported separately as the fraction that came out `uncertain`, which is the behavior the product spec asks for when two people talk at once.
- **Attribution accuracy** is computed over windows whose truth is `you` or `partner` and whose prediction is voiced. A prediction of `user` is correct for `you`, `room` is correct for `partner`. Predictions of `uncertain` count as incorrect for accuracy and are also reported as the uncertain fraction. This is the number compared against the 85% gate.
- **VAD recall** is the fraction of `you` and `partner` windows predicted voiced. **VAD precision** is the fraction of voiced predictions whose truth is not `silence`. Scripted talkers pause naturally within a block, so recall is reported as informational, not gated.
- **Talk-share error** compares `currentShare` at the end of every block against the true share computed from labels over the same trailing 120 s window. True share counts `you` seconds as user, `partner` seconds as room, `both` seconds as one second of user and one second of room each, and ignores `silence`. Evaluation points where the estimator returns uncertain are dropped from the error and counted only in the uncertain fraction. The metric reports mean absolute error in percentage points over the remaining points plus the fraction of evaluation points that were uncertain.
- The confusion matrix has truth rows `you`, `partner`, `silence` and prediction columns `user`, `room`, `uncertain`, `unvoiced`.
- **Worst blocks**: among `you` and `partner` blocks only, the three with the lowest per-block attribution accuracy, with their label, time range, mean level, and mean noise floor. `silence` and `both` blocks have no attribution accuracy and are not ranked. These feed the failure-mode write-up for cafe sessions.

`--sweep` reruns scoring over a grid of vadMarginDb in {6, 8, 10, 12} and userBandDb in {10, 12, 14, 16, 18, 20} and prints a table of attribution accuracy and uncertain fraction per cell. The sweep informs the "fixed threshold vs calibration" unresolved decision; it does not change the gated number, which always uses defaults.

`analysis.json` contains the config used, a `usesDefaultConfig` boolean, every metric above, the confusion matrix, per-block results, and the sweep table when requested. It does not contain audio samples or per-window levels; per-window data can be dumped with `--dump-windows windows.csv` for plotting.

## Report command

```
twoears-lab report [sessions/] [--out report.md]
```

Loads every `analysis.json` under the directory, groups by condition, and writes `report.md` with:

- A verdict line: GO if the mean attribution accuracy across quiet sessions analyzed with the default config is at or above 85% and at least three such sessions exist; otherwise NO-GO or INSUFFICIENT DATA. Sessions whose `analysis.json` has `usesDefaultConfig` false are listed in the tables with a "custom config" marker and excluded from the verdict.
- A table per condition: session, device, accuracy, uncertain fraction, VAD precision, VAD recall, share error.
- A failure-modes section listing the worst blocks from cafe and other sessions with their level and floor numbers, ready to be rewritten into prose.

## Error handling

- Unknown device name: list available devices and exit with status 2.
- Input format that cannot be converted to 16 kHz mono: exit with the format description.
- Session directory missing either file, or a WAV whose sample rate disagrees with `labels.json`: exit with the mismatch.
- Ctrl-C during record: stop the engine, flush the WAV, write labels with `endedEarlyAtMs` set, exit 0. Scoring later treats windows after `endedEarlyAtMs` as absent.
- Mic permission denied: print the macOS Privacy settings path and exit with status 3.

## Testing

Test-first, all deterministic, no microphone.

TwoEarsCore:

- LevelMeter: a full-scale sine reports -3.01 dBFS within 0.05 dB; a zero block reports -120.
- NoiseFloorTracker: fed 100 windows of which 90 are at -40 dB and 10 at -60 dB, reports -60; a single loud window does not move the floor.
- VadClassifier: a window at floor plus 7.9 dB is unvoiced; at 8.1 dB with in-band ZCR is voiced; white noise at high level with out-of-band ZCR is unvoiced; a 700 ms voiced run is rejected, an 800 ms run is kept.
- AttributionClassifier: levels at floor plus 12, 16, and 20 dB map to room, uncertain, user; the 3 dB margin edges are checked on both sides.
- TalkShareEstimator: 14 seconds voiced returns uncertain, 16 returns a value; a 31% uncertain mix returns uncertain; a 60 s user and 60 s room feed returns 0.5.
- Pipeline: chunks of 37 samples produce the same WindowStat sequence as chunks of 4096, compared after `finish()`; a stream ending mid-run emits the held windows on `finish()`; `currentShare` matches a standalone estimator fed the same windows.

TwoEarsLab:

- Scorer: hand-built WindowStat arrays against a small labels set produce the expected confusion matrix, margin exclusion, and both-block handling.
- Fixture: the test synthesizes a WAV following the default script with a loud tone for `you` blocks, a quiet one for `partner`, and low noise for `silence`, runs the analyzer through `TwoEarsLabKit`, and asserts accuracy above 95% and a share error under 5 points. The tone pattern is chosen so the classifier's own rules hold: within every 10 windows of a speech block, exactly one window drops to the noise level so the 10th-percentile floor stays at the noise level rather than climbing to the tone, while the nine voiced windows between dips form runs of 900 ms, above the 800 ms burst minimum. The tone frequency sits inside the ZCR band. This proves the tool end to end before any real recording.
- TurnScript: block timeline sums to the declared durations and rejects unknown labels.

## Acceptance for M0 as a deliverable

- `swift build` and `swift test` pass on this Mac.
- `twoears-lab record` produces a session with a Continuity iPhone mic and with the built-in mic.
- `twoears-lab analyze` on the synthetic fixture reports above 95% accuracy.
- `report.md` renders a verdict from at least three quiet and two cafe sessions recorded by the user. The recordings themselves are the user's task; the harness is done when it can produce and grade them.

## Out of scope

- Any watchOS code, extended-runtime sessions, or haptics.
- Per-user calibration flow. The sweep provides the data to decide whether it belongs in v1.
- Spectral or CoreML classification.
- Live keypress labeling and reference microphones.
- Plotting. The `--dump-windows` CSV is enough for a notebook if needed.
