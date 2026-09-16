# M0 Validation Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `twoears-lab`, a Swift command-line harness that records scripted, labeled conversation samples on a Mac and grades the 2Ears fixed-threshold loudness classifier against the spec's 85% attribution-accuracy gate.

**Architecture:** One Swift package with three targets. `TwoEarsCore` is the pure classifier library (level, noise floor, VAD, attribution, talk share, pipeline) with no platform audio imports, written so it moves into the watchOS app unchanged. `TwoEarsLabKit` holds everything lab-specific (WAV I/O, turn scripts, labels, scorer, analyzer, reporter, Core Audio capture). `TwoEarsLab` is a thin ArgumentParser executable over the kit.

**Tech Stack:** Swift 6.4 toolchain (Xcode 27), swift-tools-version 6.0 with Swift 5 language mode, XCTest, swift-argument-parser 1.8.2, AVFoundation and CoreAudio for capture only. Own PCM16 WAV reader/writer so tests never touch AVFoundation.

**Spec:** `docs/superpowers/specs/2026-09-15-m0-validation-harness-design.md`. Read it before starting. Every constant below comes from it.

**Conventions for every task:**
- Run tests with `swift test --filter <TestClassName>` for one class, `swift test` for all.
- Commit with `git -c user.name="Daniel Green" -c user.email="dg@danielpgreen.com" commit -m "..."` unless git identity has been configured globally by then. Every commit message ends with a blank line and `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Tests use XCTest. Test files import the module under test with `@testable import`.
- Never write audio to disk from `TwoEarsCore`. It has no file APIs at all.

---

## File structure

```
Package.swift
README.md
Scripts/default.json
Sources/TwoEarsCore/ClassifierConfig.swift      tunable constants, Codable with partial-override decoding
Sources/TwoEarsCore/WindowStat.swift            Attribution enum and per-window record
Sources/TwoEarsCore/LevelMeter.swift            RMS to dBFS and zero-crossing rate
Sources/TwoEarsCore/NoiseFloorTracker.swift     ring buffer, nearest-rank percentile
Sources/TwoEarsCore/VadClassifier.swift         margin plus ZCR band, burst rejection with delayed emit
Sources/TwoEarsCore/AttributionClassifier.swift user / room / uncertain bands
Sources/TwoEarsCore/TalkShareEstimator.swift    trailing window share with evidence gate
Sources/TwoEarsCore/Pipeline.swift              chunk buffering, stage wiring, finish(), currentShare
Sources/TwoEarsLabKit/WavFile.swift             PCM16 mono WAV read and write
Sources/TwoEarsLabKit/TurnScript.swift          script model, default script, timeline expansion
Sources/TwoEarsLabKit/SessionLabels.swift       labels.json model and session directory helpers
Sources/TwoEarsLabKit/Scorer.swift              truth alignment, confusion, metrics, per-block, share error
Sources/TwoEarsLabKit/Analysis.swift            analysis.json model
Sources/TwoEarsLabKit/Analyzer.swift            WAV to windows to score, sweep, CSV dump
Sources/TwoEarsLabKit/Reporter.swift            aggregate report.md with verdict
Sources/TwoEarsLabKit/InputDevices.swift        Core Audio input device listing
Sources/TwoEarsLabKit/AudioCapture.swift        AVAudioEngine capture to 16 kHz mono Float32
Sources/TwoEarsLab/Lab.swift                    root command
Sources/TwoEarsLab/DevicesCommand.swift
Sources/TwoEarsLab/RecordCommand.swift          prompts, countdown, Ctrl-C, session writing
Sources/TwoEarsLab/AnalyzeCommand.swift
Sources/TwoEarsLab/ReportCommand.swift
Tests/TwoEarsCoreTests/Signal.swift             synthetic signal helpers shared by core tests
Tests/TwoEarsCoreTests/LevelMeterTests.swift
Tests/TwoEarsCoreTests/NoiseFloorTrackerTests.swift
Tests/TwoEarsCoreTests/VadClassifierTests.swift
Tests/TwoEarsCoreTests/AttributionClassifierTests.swift
Tests/TwoEarsCoreTests/TalkShareEstimatorTests.swift
Tests/TwoEarsCoreTests/PipelineTests.swift
Tests/TwoEarsCoreTests/ClassifierConfigTests.swift
Tests/TwoEarsLabKitTests/WavFileTests.swift
Tests/TwoEarsLabKitTests/TurnScriptTests.swift
Tests/TwoEarsLabKitTests/ScorerTests.swift
Tests/TwoEarsLabKitTests/SyntheticSession.swift  fixture generator shared by analyzer and reporter tests
Tests/TwoEarsLabKitTests/AnalyzerTests.swift
Tests/TwoEarsLabKitTests/ReporterTests.swift
```

---

### Task 1: Package scaffold

**Files:**
- Create: `Package.swift`
- Create: `README.md`
- Create: `Sources/TwoEarsCore/WindowStat.swift` (placeholder content replaced in Task 2)
- Create: `Sources/TwoEarsLabKit/Placeholder.swift` (deleted in Task 8)
- Create: `Sources/TwoEarsLab/Lab.swift`
- Create: `Tests/TwoEarsCoreTests/Signal.swift`
- Create: `Tests/TwoEarsLabKitTests/SyntheticSession.swift` (placeholder, filled in Task 11)

- [ ] **Step 1: Write Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TwoEars",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TwoEarsCore", targets: ["TwoEarsCore"]),
        .library(name: "TwoEarsLabKit", targets: ["TwoEarsLabKit"]),
        .executable(name: "twoears-lab", targets: ["TwoEarsLab"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
    ],
    targets: [
        .target(name: "TwoEarsCore"),
        .target(name: "TwoEarsLabKit", dependencies: ["TwoEarsCore"]),
        .executableTarget(
            name: "TwoEarsLab",
            dependencies: [
                "TwoEarsCore",
                "TwoEarsLabKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "TwoEarsCoreTests", dependencies: ["TwoEarsCore"]),
        .testTarget(name: "TwoEarsLabKitTests", dependencies: ["TwoEarsCore", "TwoEarsLabKit"]),
    ],
    swiftLanguageModes: [.v5]
)
```

- [ ] **Step 2: Write placeholder sources so every target compiles**

`Sources/TwoEarsCore/WindowStat.swift`:

```swift
public enum Attribution: String, Codable, Sendable, CaseIterable {
    case user, room, uncertain
}
```

`Sources/TwoEarsLabKit/Placeholder.swift`:

```swift
import TwoEarsCore
public enum LabKitPlaceholder {}
```

`Sources/TwoEarsLab/Lab.swift`:

```swift
import ArgumentParser
import TwoEarsLabKit

@main
struct Lab: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "twoears-lab",
        abstract: "2Ears M0 validation harness: record labeled samples and grade the loudness classifier.",
        subcommands: []
    )
}
```

`Tests/TwoEarsCoreTests/Signal.swift`:

```swift
import Foundation

/// Synthetic signal helpers. All functions return Float samples at 16 kHz unless stated.
enum Signal {
    static let sampleRate = 16000

    /// Sine at `hz` with peak amplitude `amplitude`, `count` samples, starting at `phase` samples in.
    static func sine(hz: Double, amplitude: Double, count: Int, phase: Int = 0) -> [Float] {
        (0..<count).map { i in
            Float(amplitude * sin(2 * .pi * hz * Double(i + phase) / Double(sampleRate)))
        }
    }

    /// Sine whose RMS is `dbfs` decibels below full scale. RMS of a sine is amplitude / sqrt(2).
    static func sine(hz: Double, dbfs: Double, count: Int, phase: Int = 0) -> [Float] {
        let amplitude = pow(10, dbfs / 20) * 2.0.squareRoot()
        return sine(hz: hz, amplitude: amplitude, count: count, phase: phase)
    }

    /// Deterministic white noise with RMS at `dbfs`. Uses a fixed LCG so tests are repeatable.
    static func noise(dbfs: Double, count: Int, seed: UInt64 = 1) -> [Float] {
        var state = seed
        var raw: [Double] = []
        raw.reserveCapacity(count)
        for _ in 0..<count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            raw.append(Double(state >> 11) / Double(1 << 53) * 2 - 1)
        }
        let rms = (raw.reduce(0) { $0 + $1 * $1 } / Double(count)).squareRoot()
        let gain = pow(10, dbfs / 20) / rms
        return raw.map { Float($0 * gain) }
    }

    static func silence(count: Int) -> [Float] { [Float](repeating: 0, count: count) }

    /// `windows` 100 ms windows of a 200 Hz tone at `dbfs`, with every tenth window replaced by
    /// noise at `noiseDb`. The dips keep the noise floor anchored at the noise level (the floor is a
    /// 10th percentile over 100 windows) while the nine-window runs stay above the 800 ms burst minimum.
    static func dippedTone(dbfs: Double, noiseDb: Double, windows: Int, phase: Int = 0) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(windows * 1600)
        for w in 0..<windows {
            if w % 10 == 9 {
                out += noise(dbfs: noiseDb, count: 1600, seed: UInt64(w + 7))
            } else {
                out += sine(hz: 200, dbfs: dbfs, count: 1600, phase: phase + out.count)
            }
        }
        return out
    }
}
```

`Tests/TwoEarsLabKitTests/SyntheticSession.swift`:

```swift
import Foundation
@testable import TwoEarsLabKit

enum SyntheticSession {}
```

- [ ] **Step 3: Write README.md**

```markdown
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
```

- [ ] **Step 4: Build and run the empty test suite**

Run: `swift build && swift test`
Expected: build succeeds, resolves swift-argument-parser 1.8.x, tests report `Executed 0 tests`.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Package.resolved README.md Sources Tests
git commit -m "Scaffold TwoEars package with core, lab kit, and CLI targets"
```

---

### Task 2: ClassifierConfig, WindowStat, LevelMeter

**Files:**
- Create: `Sources/TwoEarsCore/ClassifierConfig.swift`
- Modify: `Sources/TwoEarsCore/WindowStat.swift`
- Create: `Sources/TwoEarsCore/LevelMeter.swift`
- Test: `Tests/TwoEarsCoreTests/ClassifierConfigTests.swift`
- Test: `Tests/TwoEarsCoreTests/LevelMeterTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/TwoEarsCoreTests/ClassifierConfigTests.swift`:

```swift
import XCTest
@testable import TwoEarsCore

final class ClassifierConfigTests: XCTestCase {
    func testDefaultsMatchSpec() {
        let c = ClassifierConfig.default
        XCTAssertEqual(c.sampleRate, 16000)
        XCTAssertEqual(c.windowMs, 100)
        XCTAssertEqual(c.floorTrailingSec, 10)
        XCTAssertEqual(c.floorPercentile, 0.10)
        XCTAssertEqual(c.vadMarginDb, 8)
        XCTAssertEqual(c.zcrMin, 0.01)
        XCTAssertEqual(c.zcrMax, 0.20)
        XCTAssertEqual(c.minBurstMs, 800)
        XCTAssertEqual(c.userBandDb, 16)
        XCTAssertEqual(c.uncertainMarginDb, 3)
        XCTAssertEqual(c.shareWindowSec, 120)
        XCTAssertEqual(c.minVoicedSec, 15)
        XCTAssertEqual(c.maxUncertainFraction, 0.30)
    }

    func testDerivedCounts() {
        let c = ClassifierConfig.default
        XCTAssertEqual(c.samplesPerWindow, 1600)
        XCTAssertEqual(c.floorWindowCount, 100)
        XCTAssertEqual(c.minBurstWindows, 8)
        XCTAssertEqual(c.shareWindowCount, 1200)
    }

    func testPartialJsonOverridesOnlyNamedKeys() throws {
        let json = #"{"vadMarginDb": 10, "userBandDb": 12}"#.data(using: .utf8)!
        let c = try JSONDecoder().decode(ClassifierConfig.self, from: json)
        XCTAssertEqual(c.vadMarginDb, 10)
        XCTAssertEqual(c.userBandDb, 12)
        XCTAssertEqual(c.minBurstMs, 800)
        XCTAssertFalse(c.isDefault)
        XCTAssertTrue(ClassifierConfig.default.isDefault)
    }

    func testRoundTripsThroughJson() throws {
        var c = ClassifierConfig.default
        c.zcrMax = 0.25
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(ClassifierConfig.self, from: data)
        XCTAssertEqual(back, c)
    }
}
```

`Tests/TwoEarsCoreTests/LevelMeterTests.swift`:

```swift
import XCTest
@testable import TwoEarsCore

final class LevelMeterTests: XCTestCase {
    func testFullScaleSineIsMinusThreeDb() {
        let s = Signal.sine(hz: 200, amplitude: 1.0, count: 1600)
        XCTAssertEqual(LevelMeter.levelDb(s[...]), -3.01, accuracy: 0.05)
    }

    func testDbfsHelperProducesRequestedLevel() {
        let s = Signal.sine(hz: 200, dbfs: -40, count: 1600)
        XCTAssertEqual(LevelMeter.levelDb(s[...]), -40, accuracy: 0.05)
    }

    func testZeroBlockIsSilenceFloor() {
        XCTAssertEqual(LevelMeter.levelDb(Signal.silence(count: 1600)[...]), -120)
        XCTAssertEqual(LevelMeter.levelDb([][...]), -120)
    }

    func testZeroCrossingRateOfTone() {
        // 200 Hz at 16 kHz crosses zero 400 times per second = 0.025 per sample.
        let s = Signal.sine(hz: 200, amplitude: 0.5, count: 16000)
        XCTAssertEqual(LevelMeter.zeroCrossingRate(s[...]), 0.025, accuracy: 0.001)
    }

    func testZeroCrossingRateOfNoiseIsHigh() {
        let n = Signal.noise(dbfs: -20, count: 16000)
        XCTAssertGreaterThan(LevelMeter.zeroCrossingRate(n[...]), 0.4)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter 'ClassifierConfigTests|LevelMeterTests'`
Expected: compile errors, `ClassifierConfig` and `LevelMeter` not found.

- [ ] **Step 3: Implement ClassifierConfig**

`Sources/TwoEarsCore/ClassifierConfig.swift`:

```swift
import Foundation

/// Every tunable constant in the classifier. Defaults are the spec's starting values.
/// Decoding accepts partial JSON: unnamed keys keep their default.
public struct ClassifierConfig: Codable, Equatable, Sendable {
    public var sampleRate: Int = 16000
    public var windowMs: Int = 100
    public var floorTrailingSec: Double = 10
    public var floorPercentile: Double = 0.10
    public var vadMarginDb: Double = 8
    public var zcrMin: Double = 0.01
    public var zcrMax: Double = 0.20
    public var minBurstMs: Int = 800
    public var userBandDb: Double = 16
    public var uncertainMarginDb: Double = 3
    public var shareWindowSec: Double = 120
    public var minVoicedSec: Double = 15
    public var maxUncertainFraction: Double = 0.30

    public init() {}

    public static let `default` = ClassifierConfig()

    public var isDefault: Bool { self == ClassifierConfig.default }

    public var samplesPerWindow: Int { sampleRate * windowMs / 1000 }
    public var floorWindowCount: Int { Int(floorTrailingSec * 1000) / windowMs }
    public var minBurstWindows: Int { minBurstMs / windowMs }
    public var shareWindowCount: Int { Int(shareWindowSec * 1000) / windowMs }
    public var windowSeconds: Double { Double(windowMs) / 1000 }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ClassifierConfig()
        sampleRate = try c.decodeIfPresent(Int.self, forKey: .sampleRate) ?? d.sampleRate
        windowMs = try c.decodeIfPresent(Int.self, forKey: .windowMs) ?? d.windowMs
        floorTrailingSec = try c.decodeIfPresent(Double.self, forKey: .floorTrailingSec) ?? d.floorTrailingSec
        floorPercentile = try c.decodeIfPresent(Double.self, forKey: .floorPercentile) ?? d.floorPercentile
        vadMarginDb = try c.decodeIfPresent(Double.self, forKey: .vadMarginDb) ?? d.vadMarginDb
        zcrMin = try c.decodeIfPresent(Double.self, forKey: .zcrMin) ?? d.zcrMin
        zcrMax = try c.decodeIfPresent(Double.self, forKey: .zcrMax) ?? d.zcrMax
        minBurstMs = try c.decodeIfPresent(Int.self, forKey: .minBurstMs) ?? d.minBurstMs
        userBandDb = try c.decodeIfPresent(Double.self, forKey: .userBandDb) ?? d.userBandDb
        uncertainMarginDb = try c.decodeIfPresent(Double.self, forKey: .uncertainMarginDb) ?? d.uncertainMarginDb
        shareWindowSec = try c.decodeIfPresent(Double.self, forKey: .shareWindowSec) ?? d.shareWindowSec
        minVoicedSec = try c.decodeIfPresent(Double.self, forKey: .minVoicedSec) ?? d.minVoicedSec
        maxUncertainFraction = try c.decodeIfPresent(Double.self, forKey: .maxUncertainFraction) ?? d.maxUncertainFraction
    }
}
```

- [ ] **Step 4: Implement WindowStat and LevelMeter**

`Sources/TwoEarsCore/WindowStat.swift` (replace the placeholder):

```swift
public enum Attribution: String, Codable, Sendable, CaseIterable {
    case user, room, uncertain
}

/// One 100 ms analysis window. Everything downstream derives from these; no audio survives.
public struct WindowStat: Equatable, Sendable {
    public var index: Int
    public var startMs: Int
    public var levelDb: Double
    public var noiseFloorDb: Double
    public var zcr: Double
    public var voiced: Bool
    /// nil when unvoiced.
    public var attribution: Attribution?

    public init(index: Int, startMs: Int, levelDb: Double, noiseFloorDb: Double,
                zcr: Double, voiced: Bool, attribution: Attribution?) {
        self.index = index
        self.startMs = startMs
        self.levelDb = levelDb
        self.noiseFloorDb = noiseFloorDb
        self.zcr = zcr
        self.voiced = voiced
        self.attribution = attribution
    }
}
```

`Sources/TwoEarsCore/LevelMeter.swift`:

```swift
import Foundation

public enum LevelMeter {
    /// Reported for an all-zero or empty block instead of negative infinity.
    public static let silenceFloorDb: Double = -120

    /// RMS of the block in dBFS, clamped at `silenceFloorDb`.
    public static func levelDb(_ samples: ArraySlice<Float>) -> Double {
        guard !samples.isEmpty else { return silenceFloorDb }
        var sum: Double = 0
        for s in samples { sum += Double(s) * Double(s) }
        let rms = (sum / Double(samples.count)).squareRoot()
        guard rms > 0 else { return silenceFloorDb }
        return max(silenceFloorDb, 20 * log10(rms))
    }

    /// Sign changes between consecutive samples, divided by sample count.
    public static func zeroCrossingRate(_ samples: ArraySlice<Float>) -> Double {
        guard samples.count > 1 else { return 0 }
        var crossings = 0
        var previousNonNegative = samples[samples.startIndex] >= 0
        for s in samples.dropFirst() {
            let nonNegative = s >= 0
            if nonNegative != previousNonNegative { crossings += 1 }
            previousNonNegative = nonNegative
        }
        return Double(crossings) / Double(samples.count)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter 'ClassifierConfigTests|LevelMeterTests'`
Expected: 9 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/TwoEarsCore Tests/TwoEarsCoreTests
git commit -m "Add ClassifierConfig, WindowStat, and LevelMeter with spec defaults"
```

---

### Task 3: NoiseFloorTracker

**Files:**
- Create: `Sources/TwoEarsCore/NoiseFloorTracker.swift`
- Test: `Tests/TwoEarsCoreTests/NoiseFloorTrackerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import TwoEarsCore

final class NoiseFloorTrackerTests: XCTestCase {
    func testEmptyReportsSilenceFloor() {
        let t = NoiseFloorTracker(config: .default)
        XCTAssertEqual(t.floorDb, -120)
    }

    func testWarmupReportsMinimumSeen() {
        var t = NoiseFloorTracker(config: .default)
        for level in [-40.0, -35, -50, -45] { t.push(level) }
        XCTAssertEqual(t.floorDb, -50)
    }

    func testTenthPercentileNearestRank() {
        var t = NoiseFloorTracker(config: .default)
        for _ in 0..<90 { t.push(-40) }
        for _ in 0..<10 { t.push(-60) }
        XCTAssertEqual(t.floorDb, -60)
    }

    func testNinePercentQuietWindowsDoNotSetFloor() {
        var t = NoiseFloorTracker(config: .default)
        for _ in 0..<91 { t.push(-40) }
        for _ in 0..<9 { t.push(-60) }
        XCTAssertEqual(t.floorDb, -40)
    }

    func testSingleLoudWindowDoesNotMoveFloor() {
        var t = NoiseFloorTracker(config: .default)
        for _ in 0..<100 { t.push(-50) }
        t.push(-10)
        XCTAssertEqual(t.floorDb, -50)
    }

    func testRingBufferForgetsOldLevels() {
        var t = NoiseFloorTracker(config: .default)
        for _ in 0..<100 { t.push(-70) }
        for _ in 0..<100 { t.push(-30) }
        XCTAssertEqual(t.floorDb, -30)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter NoiseFloorTrackerTests`
Expected: compile error, `NoiseFloorTracker` not found.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Slow-adapting noise floor: nearest-rank percentile of the trailing window levels.
public struct NoiseFloorTracker: Sendable {
    private var levels: [Double] = []
    private var writeIndex = 0
    private let capacity: Int
    private let percentile: Double
    /// Below this many samples the floor is the minimum seen, per spec.
    private let warmupCount = 20

    public init(config: ClassifierConfig) {
        capacity = max(1, config.floorWindowCount)
        percentile = config.floorPercentile
        levels.reserveCapacity(capacity)
    }

    public mutating func push(_ levelDb: Double) {
        if levels.count < capacity {
            levels.append(levelDb)
        } else {
            levels[writeIndex] = levelDb
            writeIndex = (writeIndex + 1) % capacity
        }
    }

    public var floorDb: Double {
        guard !levels.isEmpty else { return LevelMeter.silenceFloorDb }
        if levels.count < warmupCount { return levels.min()! }
        let sorted = levels.sorted()
        // Nearest-rank: 1-based rank ceil(p * n), clamped to [1, n].
        let rank = min(sorted.count, max(1, Int((percentile * Double(sorted.count)).rounded(.up))))
        return sorted[rank - 1]
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter NoiseFloorTrackerTests`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/TwoEarsCore/NoiseFloorTracker.swift Tests/TwoEarsCoreTests/NoiseFloorTrackerTests.swift
git commit -m "Add NoiseFloorTracker with nearest-rank percentile"
```

---

### Task 4: VadClassifier with burst rejection

**Files:**
- Create: `Sources/TwoEarsCore/VadClassifier.swift`
- Test: `Tests/TwoEarsCoreTests/VadClassifierTests.swift`

The classifier is stateful because burst rejection cannot confirm a voiced run until it reaches `minBurstWindows`. Windows in an unconfirmed run are held and emitted later, so `process` returns zero or more finalized windows in index order.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import TwoEarsCore

final class VadClassifierTests: XCTestCase {
    private func window(_ index: Int, level: Double, floor: Double = -60, zcr: Double = 0.05) -> WindowStat {
        WindowStat(index: index, startMs: index * 100, levelDb: level, noiseFloorDb: floor,
                   zcr: zcr, voiced: false, attribution: nil)
    }

    /// Feeds `levels` in order, then finish(), returning every emitted window.
    private func run(_ levels: [Double], zcr: Double = 0.05) -> [WindowStat] {
        var vad = VadClassifier(config: .default)
        var out: [WindowStat] = []
        for (i, level) in levels.enumerated() {
            out += vad.process(window(i, level: level, zcr: zcr))
        }
        out += vad.finish()
        return out
    }

    func testBelowMarginIsUnvoiced() {
        let out = run(Array(repeating: -52.1, count: 10))   // floor -60 + 7.9
        XCTAssertEqual(out.count, 10)
        XCTAssertTrue(out.allSatisfy { !$0.voiced })
    }

    func testAboveMarginLongRunIsVoiced() {
        let out = run(Array(repeating: -51.9, count: 10))   // floor -60 + 8.1
        XCTAssertEqual(out.count, 10)
        XCTAssertTrue(out.allSatisfy { $0.voiced })
    }

    func testOutOfBandZcrIsUnvoiced() {
        let out = run(Array(repeating: -20, count: 10), zcr: 0.5)
        XCTAssertTrue(out.allSatisfy { !$0.voiced })
    }

    func testSevenWindowBurstIsRejected() {
        let levels = Array(repeating: -20.0, count: 7) + Array(repeating: -70.0, count: 3)
        let out = run(levels)
        XCTAssertEqual(out.map(\.index), Array(0..<10))
        XCTAssertTrue(out.allSatisfy { !$0.voiced })
    }

    func testEightWindowRunIsKept() {
        let levels = Array(repeating: -20.0, count: 8) + Array(repeating: -70.0, count: 3)
        let out = run(levels)
        XCTAssertEqual(out.map(\.index), Array(0..<11))
        XCTAssertEqual(out.prefix(8).map(\.voiced), Array(repeating: true, count: 8))
        XCTAssertEqual(out.suffix(3).map(\.voiced), Array(repeating: false, count: 3))
    }

    func testEmissionIsDelayedUntilRunConfirms() {
        var vad = VadClassifier(config: .default)
        var emitted: [WindowStat] = []
        for i in 0..<7 { emitted += vad.process(window(i, level: -20)) }
        XCTAssertEqual(emitted.count, 0)
        emitted += vad.process(window(7, level: -20))
        XCTAssertEqual(emitted.count, 8)
        emitted += vad.process(window(8, level: -20))
        XCTAssertEqual(emitted.count, 9)
    }

    func testFinishResolvesPendingRunAsUnvoiced() {
        var vad = VadClassifier(config: .default)
        var emitted: [WindowStat] = []
        for i in 0..<5 { emitted += vad.process(window(i, level: -20)) }
        XCTAssertEqual(emitted.count, 0)
        emitted += vad.finish()
        XCTAssertEqual(emitted.map(\.index), [0, 1, 2, 3, 4])
        XCTAssertTrue(emitted.allSatisfy { !$0.voiced })
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter VadClassifierTests`
Expected: compile error, `VadClassifier` not found.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Voice activity detection: level margin over the noise floor plus a zero-crossing band,
/// then burst rejection. Emits windows with a delay of up to `minBurstWindows`.
public struct VadClassifier: Sendable {
    private let config: ClassifierConfig
    private var pending: [WindowStat] = []
    private var inConfirmedRun = false

    public init(config: ClassifierConfig) {
        self.config = config
    }

    /// The instantaneous decision before burst rejection.
    public func rawVoiced(_ w: WindowStat) -> Bool {
        w.levelDb > w.noiseFloorDb + config.vadMarginDb
            && w.zcr >= config.zcrMin
            && w.zcr <= config.zcrMax
    }

    /// Returns the windows finalized by this input, in index order. May be empty.
    public mutating func process(_ window: WindowStat) -> [WindowStat] {
        var w = window
        if rawVoiced(w) {
            if inConfirmedRun {
                w.voiced = true
                return [w]
            }
            pending.append(w)
            if pending.count >= config.minBurstWindows {
                inConfirmedRun = true
                return flushPending(voiced: true)
            }
            return []
        }
        inConfirmedRun = false
        var out = flushPending(voiced: false)
        w.voiced = false
        out.append(w)
        return out
    }

    /// End of stream: any unconfirmed run is too short by definition.
    public mutating func finish() -> [WindowStat] {
        inConfirmedRun = false
        return flushPending(voiced: false)
    }

    private mutating func flushPending(voiced: Bool) -> [WindowStat] {
        let out = pending.map { w -> WindowStat in
            var v = w
            v.voiced = voiced
            return v
        }
        pending.removeAll(keepingCapacity: true)
        return out
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter VadClassifierTests`
Expected: 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/TwoEarsCore/VadClassifier.swift Tests/TwoEarsCoreTests/VadClassifierTests.swift
git commit -m "Add VadClassifier with delayed-emit burst rejection"
```

---

### Task 5: AttributionClassifier

**Files:**
- Create: `Sources/TwoEarsCore/AttributionClassifier.swift`
- Test: `Tests/TwoEarsCoreTests/AttributionClassifierTests.swift`

Boundary rule, with `rel = level - (floor + userBandDb)`: `rel >= uncertainMarginDb` is user, `rel <= -uncertainMarginDb` is room, strictly between is uncertain.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import TwoEarsCore

final class AttributionClassifierTests: XCTestCase {
    private func classify(_ aboveFloor: Double) -> Attribution {
        AttributionClassifier.classify(levelDb: -60 + aboveFloor, noiseFloorDb: -60, config: .default)
    }

    func testSpecExamples() {
        XCTAssertEqual(classify(12), .room)
        XCTAssertEqual(classify(16), .uncertain)
        XCTAssertEqual(classify(20), .user)
    }

    func testUpperEdge() {
        XCTAssertEqual(classify(19), .user)
        XCTAssertEqual(classify(18.99), .uncertain)
    }

    func testLowerEdge() {
        XCTAssertEqual(classify(13), .room)
        XCTAssertEqual(classify(13.01), .uncertain)
    }

    func testCustomBands() {
        var c = ClassifierConfig.default
        c.userBandDb = 10
        c.uncertainMarginDb = 1
        XCTAssertEqual(AttributionClassifier.classify(levelDb: -49, noiseFloorDb: -60, config: c), .user)
        XCTAssertEqual(AttributionClassifier.classify(levelDb: -50, noiseFloorDb: -60, config: c), .uncertain)
        XCTAssertEqual(AttributionClassifier.classify(levelDb: -51, noiseFloorDb: -60, config: c), .room)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AttributionClassifierTests`
Expected: compile error.

- [ ] **Step 3: Implement**

```swift
/// Assigns a voiced window to the wearer, the room, or uncertain from its loudness band.
public enum AttributionClassifier {
    public static func classify(levelDb: Double, noiseFloorDb: Double, config: ClassifierConfig) -> Attribution {
        let rel = levelDb - (noiseFloorDb + config.userBandDb)
        if rel >= config.uncertainMarginDb { return .user }
        if rel <= -config.uncertainMarginDb { return .room }
        return .uncertain
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AttributionClassifierTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/TwoEarsCore/AttributionClassifier.swift Tests/TwoEarsCoreTests/AttributionClassifierTests.swift
git commit -m "Add AttributionClassifier loudness bands"
```

---

### Task 6: TalkShareEstimator

**Files:**
- Create: `Sources/TwoEarsCore/TalkShareEstimator.swift`
- Test: `Tests/TwoEarsCoreTests/TalkShareEstimatorTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import TwoEarsCore

final class TalkShareEstimatorTests: XCTestCase {
    private func feed(_ estimator: inout TalkShareEstimator, _ attribution: Attribution?, count: Int) {
        for _ in 0..<count {
            estimator.push(WindowStat(index: 0, startMs: 0, levelDb: 0, noiseFloorDb: 0, zcr: 0,
                                      voiced: attribution != nil, attribution: attribution))
        }
    }

    func testEmptyIsUncertain() {
        let e = TalkShareEstimator(config: .default)
        XCTAssertEqual(e.share, .uncertain)
    }

    func testFourteenSecondsVoicedIsUncertain() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 140)
        XCTAssertEqual(e.share, .uncertain)
    }

    func testSixteenSecondsVoicedGivesValue() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 160)
        XCTAssertEqual(e.share, .value(1.0))
    }

    func testThirtyOnePercentUncertainIsUncertain() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 690)
        feed(&e, .uncertain, count: 310)
        XCTAssertEqual(e.share, .uncertain)
    }

    func testThirtyPercentUncertainStillReports() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 700)
        feed(&e, .uncertain, count: 300)
        XCTAssertEqual(e.share, .value(1.0))
    }

    func testEqualUserAndRoomIsHalf() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 600)
        feed(&e, .room, count: 600)
        XCTAssertEqual(e.share, .value(0.5))
    }

    func testUnvoicedWindowsDoNotCount() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 200)
        feed(&e, nil, count: 500)
        feed(&e, .room, count: 200)
        XCTAssertEqual(e.share, .value(0.5))
    }

    func testTrailingWindowForgetsOldWindows() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .room, count: 1200)
        feed(&e, .user, count: 1200)
        XCTAssertEqual(e.share, .value(1.0))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TalkShareEstimatorTests`
Expected: compile error.

- [ ] **Step 3: Implement**

```swift
import Foundation

public enum TalkShare: Equatable, Sendable {
    /// Wearer voiced time over all attributed voiced time, 0...1.
    case value(Double)
    case uncertain
}

/// Trailing-window talk share with the spec's minimum-evidence gate.
public struct TalkShareEstimator: Sendable {
    private let config: ClassifierConfig
    /// nil = unvoiced window.
    private var ring: [Attribution?] = []
    private var writeIndex = 0
    private let capacity: Int

    public init(config: ClassifierConfig) {
        self.config = config
        capacity = max(1, config.shareWindowCount)
        ring.reserveCapacity(capacity)
    }

    public mutating func push(_ window: WindowStat) {
        let entry: Attribution? = window.voiced ? window.attribution : nil
        if ring.count < capacity {
            ring.append(entry)
        } else {
            ring[writeIndex] = entry
            writeIndex = (writeIndex + 1) % capacity
        }
    }

    public var share: TalkShare {
        var user = 0, room = 0, uncertain = 0
        for entry in ring {
            switch entry {
            case .user?: user += 1
            case .room?: room += 1
            case .uncertain?: uncertain += 1
            case nil: break
            }
        }
        let voiced = user + room + uncertain
        guard voiced > 0 else { return .uncertain }
        if Double(voiced) * config.windowSeconds < config.minVoicedSec { return .uncertain }
        if Double(uncertain) / Double(voiced) > config.maxUncertainFraction { return .uncertain }
        guard user + room > 0 else { return .uncertain }
        return .value(Double(user) / Double(user + room))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TalkShareEstimatorTests`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/TwoEarsCore/TalkShareEstimator.swift Tests/TwoEarsCoreTests/TalkShareEstimatorTests.swift
git commit -m "Add TalkShareEstimator with evidence gate"
```

---

### Task 7: Pipeline

**Files:**
- Create: `Sources/TwoEarsCore/Pipeline.swift`
- Test: `Tests/TwoEarsCoreTests/PipelineTests.swift`

`Pipeline` is the one object the watch app will use. It buffers arbitrary chunks into whole windows, runs the stages, and exposes `currentShare`.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import TwoEarsCore

final class PipelineTests: XCTestCase {
    /// 3 s room noise at -60, 3 s loud tone at -30 (wearer), 3 s quiet tone at -48 (room).
    private func threeSegmentSignal() -> [Float] {
        Signal.noise(dbfs: -60, count: 3 * 16000)
            + Signal.sine(hz: 200, dbfs: -30, count: 3 * 16000)
            + Signal.sine(hz: 200, dbfs: -48, count: 3 * 16000)
    }

    private func runAll(_ samples: [Float], chunk: Int) -> (windows: [WindowStat], share: TalkShare) {
        let p = Pipeline(config: .default)
        var out: [WindowStat] = []
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + chunk)
            out += p.process(Array(samples[start..<end]))
            start = end
        }
        out += p.finish()
        return (out, p.currentShare)
    }

    func testAttributesSegmentsAsExpected() {
        let (w, _) = runAll(threeSegmentSignal(), chunk: 4096)
        XCTAssertEqual(w.count, 90)
        XCTAssertEqual(w.map(\.index), Array(0..<90))
        XCTAssertEqual(w[10].startMs, 1000)
        XCTAssertTrue(w[0..<30].allSatisfy { !$0.voiced && $0.attribution == nil })
        XCTAssertTrue(w[30..<60].allSatisfy { $0.voiced && $0.attribution == .user })
        XCTAssertTrue(w[60..<90].allSatisfy { $0.voiced && $0.attribution == .room })
    }

    func testChunkSizeDoesNotChangeOutput() {
        let s = threeSegmentSignal()
        XCTAssertEqual(runAll(s, chunk: 37).windows, runAll(s, chunk: 4096).windows)
    }

    func testFinishEmitsHeldWindowsAndDropsPartialWindow() {
        let s = Signal.noise(dbfs: -60, count: 2 * 16000)
            + Signal.sine(hz: 200, dbfs: -20, count: 5 * 1600 + 700)
        let p = Pipeline(config: .default)
        let before = p.process(s)
        XCTAssertEqual(before.count, 20)
        let held = p.finish()
        XCTAssertEqual(held.map(\.index), [20, 21, 22, 23, 24])
        XCTAssertTrue(held.allSatisfy { !$0.voiced })
        XCTAssertEqual(p.finish().count, 0)
    }

    func testCurrentShareMatchesStandaloneEstimator() {
        let (w, share) = runAll(threeSegmentSignal(), chunk: 1000)
        var e = TalkShareEstimator(config: .default)
        for window in w { e.push(window) }
        XCTAssertEqual(share, e.share)
        XCTAssertEqual(share, .uncertain)   // only 6 s voiced, under the 15 s gate
    }

    func testShareBecomesValueWithEnoughEvidence() {
        // Continuous tone for more than 10 s would drag the noise floor up to the tone level and
        // mute VAD, so both speech segments use the dipped pattern (see Signal.dippedTone).
        let s = Signal.noise(dbfs: -60, count: 3 * 16000)
            + Signal.dippedTone(dbfs: -30, noiseDb: -60, windows: 100)
            + Signal.dippedTone(dbfs: -48, noiseDb: -60, windows: 100)
        let (_, share) = runAll(s, chunk: 4096)
        guard case .value(let v) = share else { return XCTFail("expected a value, got \(share)") }
        XCTAssertEqual(v, 0.5, accuracy: 0.02)   // 90 user and 90 room voiced windows
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PipelineTests`
Expected: compile error, `Pipeline` not found.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Runs raw samples through level, noise floor, VAD, attribution, and talk share.
/// Accepts chunks of any size. Call `finish()` at end of stream.
public final class Pipeline {
    public let config: ClassifierConfig
    private var buffer: [Float] = []
    private var nextIndex = 0
    private var floor: NoiseFloorTracker
    private var vad: VadClassifier
    private var estimator: TalkShareEstimator

    public init(config: ClassifierConfig) {
        self.config = config
        floor = NoiseFloorTracker(config: config)
        vad = VadClassifier(config: config)
        estimator = TalkShareEstimator(config: config)
        buffer.reserveCapacity(config.samplesPerWindow * 2)
    }

    /// Talk share as of the last emitted window.
    public var currentShare: TalkShare { estimator.share }

    /// Windows completed by this chunk, in index order. Windows held by burst rejection
    /// are emitted by a later call or by `finish()`.
    public func process(_ samples: [Float]) -> [WindowStat] {
        buffer.append(contentsOf: samples)
        let n = config.samplesPerWindow
        var out: [WindowStat] = []
        var start = 0
        while buffer.count - start >= n {
            let slice = buffer[start..<(start + n)]
            out += analyze(slice)
            start += n
        }
        if start > 0 { buffer.removeFirst(start) }
        return out
    }

    /// Resolves any pending voiced run as unvoiced and drops a partial trailing window.
    public func finish() -> [WindowStat] {
        buffer.removeAll(keepingCapacity: true)
        return emit(vad.finish())
    }

    private func analyze(_ slice: ArraySlice<Float>) -> [WindowStat] {
        let level = LevelMeter.levelDb(slice)
        let zcr = LevelMeter.zeroCrossingRate(slice)
        floor.push(level)
        let window = WindowStat(index: nextIndex, startMs: nextIndex * config.windowMs,
                                levelDb: level, noiseFloorDb: floor.floorDb, zcr: zcr,
                                voiced: false, attribution: nil)
        nextIndex += 1
        return emit(vad.process(window))
    }

    private func emit(_ windows: [WindowStat]) -> [WindowStat] {
        windows.map { w in
            var v = w
            v.attribution = v.voiced
                ? AttributionClassifier.classify(levelDb: v.levelDb, noiseFloorDb: v.noiseFloorDb, config: config)
                : nil
            estimator.push(v)
            return v
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter PipelineTests`
Expected: 5 tests pass. If `testAttributesSegmentsAsExpected` fails on the first tone window, check that the noise floor is still -60 there (30 noise windows precede it) and that the tone's first window is a full 1600 samples.

- [ ] **Step 5: Run the whole core suite and commit**

Run: `swift test --filter TwoEarsCoreTests`
Expected: all core tests pass.

```bash
git add Sources/TwoEarsCore/Pipeline.swift Tests/TwoEarsCoreTests/PipelineTests.swift
git commit -m "Add Pipeline wiring the classifier stages with finish and currentShare"
```

---

### Task 8: WavFile (PCM16 read and write)

**Files:**
- Delete: `Sources/TwoEarsLabKit/Placeholder.swift`
- Create: `Sources/TwoEarsLabKit/WavFile.swift`
- Test: `Tests/TwoEarsLabKitTests/WavFileTests.swift`

Own WAV code keeps tests off AVFoundation and makes the fixture generator trivial. Only PCM16 is supported; the recorder writes PCM16 mono, and the reader averages channels if handed a multi-channel file.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import TwoEarsLabKit

final class WavFileTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tmp)
    }

    func testRoundTripPreservesSamplesWithin16BitStep() throws {
        let url = tmp.appendingPathComponent("a.wav")
        let original: [Float] = (0..<16000).map { Float(sin(Double($0) / 25)) * 0.8 }
        try WavFile.write(samples: original, sampleRate: 16000, to: url)
        let back = try WavFile.read(url)
        XCTAssertEqual(back.sampleRate, 16000)
        XCTAssertEqual(back.samples.count, original.count)
        // Writer scales by 32767 and rounds; reader divides by 32768. Worst case is about 1.3 steps.
        for (a, b) in zip(original, back.samples) {
            XCTAssertEqual(a, b, accuracy: 1.5 / 32768 + 1e-6)
        }
    }

    func testWriteClampsOutOfRange() throws {
        let url = tmp.appendingPathComponent("c.wav")
        try WavFile.write(samples: [2.0, -2.0, 0], sampleRate: 16000, to: url)
        let back = try WavFile.read(url).samples
        XCTAssertEqual(back[0], 32767.0 / 32768, accuracy: 1e-6)
        XCTAssertEqual(back[1], -32767.0 / 32768, accuracy: 1e-6)
        XCTAssertEqual(back[2], 0)
    }

    func testHeaderSizesAreCorrect() throws {
        let url = tmp.appendingPathComponent("h.wav")
        try WavFile.write(samples: [Float](repeating: 0, count: 100), sampleRate: 16000, to: url)
        let data = try Data(contentsOf: url)
        XCTAssertEqual(data.count, 44 + 200)
        XCTAssertEqual(String(decoding: data[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
    }

    func testRejectsNonWav() throws {
        let url = tmp.appendingPathComponent("x.wav")
        try Data("hello".utf8).write(to: url)
        XCTAssertThrowsError(try WavFile.read(url))
    }

    func testStereoIsAveragedToMono() throws {
        // Hand-build a 2-channel, 2-frame PCM16 file: frame 0 = (16384, 0), frame 1 = (-16384, -16384).
        var d = Data()
        func u16(_ v: UInt16) { d.append(UInt8(v & 0xff)); d.append(UInt8(v >> 8)) }
        func u32(_ v: UInt32) { u16(UInt16(v & 0xffff)); u16(UInt16(v >> 16)) }
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + 8)
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(2); u32(16000); u32(64000); u16(4); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(8)
        u16(16384); u16(0); u16(UInt16(bitPattern: -16384)); u16(UInt16(bitPattern: -16384))
        let url = tmp.appendingPathComponent("s.wav")
        try d.write(to: url)
        let back = try WavFile.read(url)
        XCTAssertEqual(back.samples.count, 2)
        XCTAssertEqual(back.samples[0], 0.25, accuracy: 1e-6)
        XCTAssertEqual(back.samples[1], -0.5, accuracy: 1e-6)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter WavFileTests`
Expected: compile error, `WavFile` not found.

- [ ] **Step 3: Delete the placeholder and implement**

```bash
rm Sources/TwoEarsLabKit/Placeholder.swift
```

`Sources/TwoEarsLabKit/WavFile.swift`:

```swift
import Foundation

public enum WavFileError: Error, Equatable, CustomStringConvertible {
    case notRiff
    case unsupportedFormat(String)
    case truncated

    public var description: String {
        switch self {
        case .notRiff: return "not a RIFF/WAVE file"
        case .unsupportedFormat(let s): return "unsupported WAV format: \(s)"
        case .truncated: return "WAV file is truncated"
        }
    }
}

/// Minimal PCM16 little-endian WAV I/O. Writes mono; reads any channel count and averages to mono.
public enum WavFile {
    public static func write(samples: [Float], sampleRate: Int, to url: URL) throws {
        let dataBytes = samples.count * 2
        var data = Data(capacity: 44 + dataBytes)
        func append<T: FixedWidthInteger>(_ v: T) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + dataBytes))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16))
        append(UInt16(1))                       // PCM
        append(UInt16(1))                       // channels
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))          // byte rate
        append(UInt16(2))                       // block align
        append(UInt16(16))                      // bits per sample
        data.append(contentsOf: Array("data".utf8)); append(UInt32(dataBytes))
        for s in samples {
            let clamped = max(-1, min(1, s))
            append(Int16((clamped * 32767).rounded()))
        }
        try data.write(to: url)
    }

    public static func read(_ url: URL) throws -> (sampleRate: Int, samples: [Float]) {
        let bytes = [UInt8](try Data(contentsOf: url))
        guard bytes.count >= 12,
              String(decoding: bytes[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: bytes[8..<12], as: UTF8.self) == "WAVE"
        else { throw WavFileError.notRiff }

        func u16(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
        func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }

        var offset = 12
        var format = 0, channels = 0, sampleRate = 0, bits = 0
        var dataRange: Range<Int>?
        while offset + 8 <= bytes.count {
            let id = String(decoding: bytes[offset..<offset + 4], as: UTF8.self)
            let size = u32(offset + 4)
            let body = offset + 8
            if id == "fmt " {
                guard body + 16 <= bytes.count else { throw WavFileError.truncated }
                format = u16(body); channels = u16(body + 2); sampleRate = u32(body + 4); bits = u16(body + 14)
            } else if id == "data" {
                guard body + size <= bytes.count else { throw WavFileError.truncated }
                dataRange = body..<(body + size)
            }
            offset = body + size + (size & 1)
        }
        guard format == 1, bits == 16 else {
            throw WavFileError.unsupportedFormat("format \(format), \(bits)-bit; need PCM 16-bit")
        }
        guard channels >= 1, let range = dataRange else { throw WavFileError.truncated }

        let frameCount = range.count / (2 * channels)
        var samples = [Float]()
        samples.reserveCapacity(frameCount)
        var at = range.lowerBound
        for _ in 0..<frameCount {
            var acc: Float = 0
            for _ in 0..<channels {
                let v = Int16(bitPattern: UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8)
                acc += Float(v) / 32768
                at += 2
            }
            samples.append(acc / Float(channels))
        }
        return (sampleRate, samples)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter WavFileTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A Sources/TwoEarsLabKit Tests/TwoEarsLabKitTests/WavFileTests.swift
git commit -m "Add PCM16 WavFile reader and writer"
```

---

### Task 9: TurnScript and SessionLabels

**Files:**
- Create: `Sources/TwoEarsLabKit/TurnScript.swift`
- Create: `Sources/TwoEarsLabKit/SessionLabels.swift`
- Create: `Scripts/default.json`
- Test: `Tests/TwoEarsLabKitTests/TurnScriptTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import TwoEarsLabKit

final class TurnScriptTests: XCTestCase {
    func testDefaultScriptTotalsOneNinetySeconds() {
        XCTAssertEqual(TurnScript.default.totalMs, 190_000)
        XCTAssertEqual(TurnScript.default.blocks.count, 13)
        XCTAssertEqual(TurnScript.default.name, "default")
    }

    func testTimelineIsContiguous() {
        let t = TurnScript.default.timeline()
        XCTAssertEqual(t.first?.startMs, 0)
        XCTAssertEqual(t.last?.endMs, 190_000)
        for (a, b) in zip(t, t.dropFirst()) { XCTAssertEqual(a.endMs, b.startMs) }
        XCTAssertEqual(t[1], LabelBlock(label: .you, startMs: 5000, endMs: 25_000))
    }

    func testDecodesJson() throws {
        let json = #"{"name":"tiny","blocks":[{"label":"you","seconds":1.5},{"label":"silence","seconds":2}]}"#
        let s = try TurnScript.decode(Data(json.utf8))
        XCTAssertEqual(s.totalMs, 3500)
        XCTAssertEqual(s.blocks[0].label, .you)
    }

    func testRejectsUnknownLabel() {
        let json = #"{"name":"bad","blocks":[{"label":"host","seconds":1}]}"#
        XCTAssertThrowsError(try TurnScript.decode(Data(json.utf8)))
    }

    func testRejectsEmptyAndNonPositive() {
        XCTAssertThrowsError(try TurnScript.decode(Data(#"{"name":"e","blocks":[]}"#.utf8)))
        XCTAssertThrowsError(try TurnScript.decode(Data(#"{"name":"z","blocks":[{"label":"you","seconds":0}]}"#.utf8)))
    }

    func testSessionLabelsRoundTrip() throws {
        let labels = SessionLabels(recordedAt: Date(timeIntervalSince1970: 1_800_000_000),
                                   condition: "quiet", device: "Built-in Microphone", notes: "desk",
                                   sampleRate: 16000, scriptName: "default",
                                   blocks: TurnScript.default.timeline(), endedEarlyAtMs: 12_345)
        let data = try SessionFiles.encoder.encode(labels)
        let back = try SessionFiles.decoder.decode(SessionLabels.self, from: data)
        XCTAssertEqual(back, labels)
        XCTAssertEqual(back.version, 1)
    }

    func testDirectoryName() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)   // 2027-01-15T08:00:00Z
        let name = SessionFiles.directoryName(recordedAt: date, condition: "cafe", timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(name, "20270115-080000-cafe")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TurnScriptTests`
Expected: compile errors.

- [ ] **Step 3: Implement TurnScript**

`Sources/TwoEarsLabKit/TurnScript.swift`:

```swift
import Foundation

public enum TurnLabel: String, Codable, Sendable, CaseIterable {
    case you, partner, both, silence
}

/// A labeled span in a session, in milliseconds from recording start.
public struct LabelBlock: Codable, Equatable, Sendable {
    public var label: TurnLabel
    public var startMs: Int
    public var endMs: Int

    public init(label: TurnLabel, startMs: Int, endMs: Int) {
        self.label = label
        self.startMs = startMs
        self.endMs = endMs
    }

    public var durationMs: Int { endMs - startMs }
}

public enum TurnScriptError: Error, CustomStringConvertible {
    case empty
    case nonPositiveDuration(index: Int)

    public var description: String {
        switch self {
        case .empty: return "script has no blocks"
        case .nonPositiveDuration(let i): return "block \(i) has a non-positive duration"
        }
    }
}

/// The prompt sequence shown during a recording. Labels derive from it.
public struct TurnScript: Codable, Equatable, Sendable {
    public struct Block: Codable, Equatable, Sendable {
        public var label: TurnLabel
        public var seconds: Double
        public init(_ label: TurnLabel, _ seconds: Double) {
            self.label = label
            self.seconds = seconds
        }
    }

    public var name: String
    public var blocks: [Block]

    public init(name: String, blocks: [Block]) {
        self.name = name
        self.blocks = blocks
    }

    public var totalMs: Int { blocks.reduce(0) { $0 + Int(($1.seconds * 1000).rounded()) } }

    public func validate() throws {
        guard !blocks.isEmpty else { throw TurnScriptError.empty }
        for (i, b) in blocks.enumerated() where b.seconds <= 0 {
            throw TurnScriptError.nonPositiveDuration(index: i)
        }
    }

    public func timeline() -> [LabelBlock] {
        var out: [LabelBlock] = []
        var cursor = 0
        for b in blocks {
            let end = cursor + Int((b.seconds * 1000).rounded())
            out.append(LabelBlock(label: b.label, startMs: cursor, endMs: end))
            cursor = end
        }
        return out
    }

    public static func decode(_ data: Data) throws -> TurnScript {
        let script = try JSONDecoder().decode(TurnScript.self, from: data)
        try script.validate()
        return script
    }

    public static func load(from url: URL) throws -> TurnScript {
        try decode(try Data(contentsOf: url))
    }

    public static let `default` = TurnScript(name: "default", blocks: [
        Block(.silence, 5), Block(.you, 20), Block(.partner, 20), Block(.you, 20), Block(.partner, 20),
        Block(.silence, 5), Block(.both, 10), Block(.partner, 20), Block(.you, 20),
        Block(.silence, 5), Block(.partner, 20), Block(.you, 20), Block(.silence, 5),
    ])
}
```

- [ ] **Step 4: Implement SessionLabels and SessionFiles**

`Sources/TwoEarsLabKit/SessionLabels.swift`:

```swift
import Foundation

/// labels.json: the ground-truth timeline plus recording metadata.
public struct SessionLabels: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var recordedAt: Date
    public var condition: String
    public var device: String
    public var notes: String?
    public var sampleRate: Int
    public var scriptName: String
    public var blocks: [LabelBlock]
    /// Set when recording stopped before the script finished. Windows at or after it are absent.
    public var endedEarlyAtMs: Int?

    public init(recordedAt: Date, condition: String, device: String, notes: String?,
                sampleRate: Int, scriptName: String, blocks: [LabelBlock], endedEarlyAtMs: Int?) {
        self.recordedAt = recordedAt
        self.condition = condition
        self.device = device
        self.notes = notes
        self.sampleRate = sampleRate
        self.scriptName = scriptName
        self.blocks = blocks
        self.endedEarlyAtMs = endedEarlyAtMs
    }

    public var scriptTotalMs: Int { blocks.last?.endMs ?? 0 }
}

/// File names and codecs shared by record, analyze, and report.
public enum SessionFiles {
    public static let audioName = "audio.wav"
    public static let labelsName = "labels.json"
    public static let analysisName = "analysis.json"

    public static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    public static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public static func directoryName(recordedAt: Date, condition: String, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyyMMdd-HHmmss"
        return "\(f.string(from: recordedAt))-\(condition)"
    }

    public static func readLabels(in dir: URL) throws -> SessionLabels {
        try decoder.decode(SessionLabels.self, from: Data(contentsOf: dir.appendingPathComponent(labelsName)))
    }

    public static func writeLabels(_ labels: SessionLabels, in dir: URL) throws {
        try encoder.encode(labels).write(to: dir.appendingPathComponent(labelsName))
    }
}
```

`Scripts/default.json`:

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

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter TurnScriptTests`
Expected: 7 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/TwoEarsLabKit/TurnScript.swift Sources/TwoEarsLabKit/SessionLabels.swift Scripts/default.json Tests/TwoEarsLabKitTests/TurnScriptTests.swift
git commit -m "Add turn scripts, session labels, and session file helpers"
```

---

### Task 10: Scorer

**Files:**
- Create: `Sources/TwoEarsLabKit/Scorer.swift`
- Test: `Tests/TwoEarsLabKitTests/ScorerTests.swift`

Scoring rules from the spec, restated as code contracts:
- Truth for a window is the block containing its `startMs`. A window whose `startMs` is less than 500 ms after a block start, or 500 ms or less before a block end, is `margin` and excluded from everything except the margin count.
- Windows at or after `endedEarlyAtMs`, or outside every block, are absent and ignored.
- Attribution accuracy: truth `you` or `partner`, prediction voiced. `user` is correct for `you`, `room` for `partner`. `uncertain` is wrong and counted in `uncertainFraction`.
- VAD recall: fraction of `you`/`partner` windows predicted voiced. VAD precision: fraction of voiced predictions whose truth is not `silence` (so `both` counts as correct).
- `both` windows report only `bothUncertainFraction` = uncertain / voiced within `both` blocks.
- Per-block accuracy exists only for `you`/`partner` blocks; worst blocks are the three lowest.
- Share error: a fresh `TalkShareEstimator` is fed windows in order; at each block end `T` (capped at `endedEarlyAtMs`), compare its share with the true share over `[T - shareWindowSec*1000, T)`, where `you` overlap counts as user, `partner` as room, `both` as both. Points with no true voiced time are skipped. Estimator-uncertain points are dropped from the error and counted in `shareUncertainFraction`.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
import TwoEarsCore
@testable import TwoEarsLabKit

final class ScorerTests: XCTestCase {
    enum Pred { case user, room, uncertain, unvoiced }

    private func window(_ startMs: Int, _ pred: Pred, level: Double = -30, floor: Double = -60) -> WindowStat {
        let attribution: Attribution?
        switch pred {
        case .user: attribution = .user
        case .room: attribution = .room
        case .uncertain: attribution = .uncertain
        case .unvoiced: attribution = nil
        }
        return WindowStat(index: startMs / 100, startMs: startMs, levelDb: level, noiseFloorDb: floor,
                          zcr: 0.05, voiced: pred != .unvoiced, attribution: attribution)
    }

    private func labels(_ blocks: [LabelBlock], endedEarlyAtMs: Int? = nil) -> SessionLabels {
        SessionLabels(recordedAt: Date(), condition: "quiet", device: "test", notes: nil,
                      sampleRate: 16000, scriptName: "test", blocks: blocks, endedEarlyAtMs: endedEarlyAtMs)
    }

    /// silence 0-2 s, you 2-6 s, partner 6-10 s, both 10-12 s, silence 12-14 s.
    private let fiveBlocks = [
        LabelBlock(label: .silence, startMs: 0, endMs: 2000),
        LabelBlock(label: .you, startMs: 2000, endMs: 6000),
        LabelBlock(label: .partner, startMs: 6000, endMs: 10_000),
        LabelBlock(label: .both, startMs: 10_000, endMs: 12_000),
        LabelBlock(label: .silence, startMs: 12_000, endMs: 14_000),
    ]

    /// Ideal predictions for fiveBlocks: unvoiced in silence, user in you, room in partner, uncertain in both.
    private func idealWindows() -> [WindowStat] {
        (0..<140).map { i in
            let ms = i * 100
            switch ms {
            case 0..<2000, 12_000..<14_000: return window(ms, .unvoiced)
            case 2000..<6000: return window(ms, .user)
            case 6000..<10_000: return window(ms, .room)
            default: return window(ms, .uncertain)
            }
        }
    }

    func testMarginRule() {
        let l = labels(fiveBlocks)
        XCTAssertEqual(Scorer.truth(atMs: 2000, labels: l)?.isMargin, true)
        XCTAssertEqual(Scorer.truth(atMs: 2400, labels: l)?.isMargin, true)
        XCTAssertEqual(Scorer.truth(atMs: 2500, labels: l)?.isMargin, false)
        XCTAssertEqual(Scorer.truth(atMs: 5400, labels: l)?.isMargin, false)
        XCTAssertEqual(Scorer.truth(atMs: 5500, labels: l)?.isMargin, true)
        XCTAssertEqual(Scorer.truth(atMs: 2500, labels: l)?.label, .you)
        XCTAssertNil(Scorer.truth(atMs: 14_000, labels: l))
        XCTAssertNil(Scorer.truth(atMs: 3000, labels: labels(fiveBlocks, endedEarlyAtMs: 3000)))
    }

    func testIdealPredictionsScorePerfectly() {
        let r = Scorer.score(windows: idealWindows(), labels: labels(fiveBlocks), config: .default)
        XCTAssertEqual(r.attributionAccuracy, 1.0)
        XCTAssertEqual(r.attributionWindowCount, 60)      // 30 scored windows per speech block
        XCTAssertEqual(r.uncertainFraction, 0.0)
        XCTAssertEqual(r.vadRecall, 1.0)
        XCTAssertEqual(r.vadPrecision, 1.0)
        XCTAssertEqual(r.bothUncertainFraction, 1.0)
        XCTAssertEqual(r.marginWindows, 5 * 10)           // 10 margin windows per block
        XCTAssertEqual(r.scoredWindows, 140 - 50)
        XCTAssertEqual(r.confusion["you"]?["user"], 30)
        XCTAssertEqual(r.confusion["partner"]?["room"], 30)
        XCTAssertEqual(r.confusion["silence"]?["unvoiced"], 20)
        XCTAssertEqual(r.perBlock.count, 2)
        XCTAssertEqual(r.worstBlocks.count, 2)
    }

    func testWrongAndUncertainPredictionsCountAgainstAccuracy() {
        var w = idealWindows()
        w[25] = window(2500, .room)          // you block, wrong
        w[26] = window(2600, .uncertain)     // you block, uncertain
        w[65] = window(6500, .user)          // partner block, wrong
        let r = Scorer.score(windows: w, labels: labels(fiveBlocks), config: .default)
        XCTAssertEqual(r.attributionAccuracy!, 57.0 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(r.uncertainFraction!, 1.0 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(r.confusion["you"]?["room"], 1)
        XCTAssertEqual(r.confusion["you"]?["uncertain"], 1)
        XCTAssertEqual(r.worstBlocks.first?.label, .you)
        XCTAssertEqual(r.worstBlocks.first!.accuracy!, 28.0 / 30.0, accuracy: 1e-9)
    }

    func testVadMetrics() {
        var w = idealWindows()
        w[30] = window(3000, .unvoiced)      // missed speech
        w[10] = window(1000, .room)          // voiced in silence
        let r = Scorer.score(windows: w, labels: labels(fiveBlocks), config: .default)
        XCTAssertEqual(r.vadRecall!, 59.0 / 60.0, accuracy: 1e-9)
        // voiced predictions: 59 speech + 10 both (scored, non-margin) + 1 silence = 70; not-silence = 69
        XCTAssertEqual(r.vadPrecision!, 69.0 / 70.0, accuracy: 1e-9)
        XCTAssertEqual(r.attributionWindowCount, 59)
    }

    func testEndedEarlyDropsLaterWindows() {
        let r = Scorer.score(windows: idealWindows(), labels: labels(fiveBlocks, endedEarlyAtMs: 6000), config: .default)
        XCTAssertEqual(r.attributionWindowCount, 30)
        XCTAssertEqual(r.perBlock.count, 1)
    }

    func testShareErrorIsZeroForPerfectEstimate() {
        let blocks = [LabelBlock(label: .you, startMs: 0, endMs: 60_000),
                      LabelBlock(label: .partner, startMs: 60_000, endMs: 120_000)]
        let w = (0..<1200).map { i in window(i * 100, i < 600 ? .user : .room) }
        let r = Scorer.score(windows: w, labels: labels(blocks), config: .default)
        XCTAssertEqual(r.sharePointCount, 2)
        XCTAssertEqual(r.shareMeanAbsErrorPoints!, 0, accuracy: 1e-9)
        XCTAssertEqual(r.shareUncertainFraction, 0)
    }

    func testShareErrorAveragesOverPoints() {
        let blocks = [LabelBlock(label: .you, startMs: 0, endMs: 60_000),
                      LabelBlock(label: .partner, startMs: 60_000, endMs: 120_000)]
        let w = (0..<1200).map { i in window(i * 100, .user) }   // partner block misread as user
        let r = Scorer.score(windows: w, labels: labels(blocks), config: .default)
        // point 1: est 1.0 vs true 1.0 = 0; point 2: est 1.0 vs true 0.5 = 50 points.
        XCTAssertEqual(r.shareMeanAbsErrorPoints!, 25, accuracy: 1e-9)
    }

    func testShareUncertainPointsAreCountedNotAveraged() {
        let blocks = [LabelBlock(label: .you, startMs: 0, endMs: 10_000)]
        let w = (0..<100).map { i in window(i * 100, .user) }   // 10 s voiced, under the 15 s gate
        let r = Scorer.score(windows: w, labels: labels(blocks), config: .default)
        XCTAssertEqual(r.sharePointCount, 1)
        XCTAssertNil(r.shareMeanAbsErrorPoints)
        XCTAssertEqual(r.shareUncertainFraction, 1.0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ScorerTests`
Expected: compile errors.

- [ ] **Step 3: Implement**

`Sources/TwoEarsLabKit/Scorer.swift`:

```swift
import Foundation
import TwoEarsCore

public enum Prediction: String, Codable, Sendable, CaseIterable {
    case user, room, uncertain, unvoiced

    public init(_ w: WindowStat) {
        guard w.voiced, let a = w.attribution else { self = .unvoiced; return }
        switch a {
        case .user: self = .user
        case .room: self = .room
        case .uncertain: self = .uncertain
        }
    }
}

public struct BlockScore: Codable, Equatable, Sendable {
    public var label: TurnLabel
    public var startMs: Int
    public var endMs: Int
    public var scoredWindows: Int
    /// Attribution accuracy; nil for blocks that are not you/partner or had no voiced predictions.
    public var accuracy: Double?
    public var meanLevelDb: Double
    public var meanFloorDb: Double
}

public struct ScoreResult: Codable, Equatable, Sendable {
    public var scoredWindows = 0
    public var marginWindows = 0
    public var attributionWindowCount = 0
    public var attributionAccuracy: Double?
    public var uncertainFraction: Double?
    public var vadRecall: Double?
    public var vadPrecision: Double?
    public var bothUncertainFraction: Double?
    /// truth ("you"/"partner"/"silence") -> prediction -> count
    public var confusion: [String: [String: Int]] = [:]
    public var perBlock: [BlockScore] = []
    public var worstBlocks: [BlockScore] = []
    public var sharePointCount = 0
    public var shareMeanAbsErrorPoints: Double?
    public var shareUncertainFraction: Double?

    public init() {}
}

public enum Scorer {
    public static let marginMs = 500

    public struct Truth: Equatable {
        public var label: TurnLabel
        public var blockIndex: Int
        public var isMargin: Bool
    }

    /// nil when the time is absent (after endedEarlyAtMs or outside every block).
    public static func truth(atMs t: Int, labels: SessionLabels) -> Truth? {
        if let early = labels.endedEarlyAtMs, t >= early { return nil }
        guard let i = labels.blocks.firstIndex(where: { t >= $0.startMs && t < $0.endMs }) else { return nil }
        let b = labels.blocks[i]
        let isMargin = (t - b.startMs) < marginMs || (b.endMs - t) <= marginMs
        return Truth(label: b.label, blockIndex: i, isMargin: isMargin)
    }

    public static func score(windows: [WindowStat], labels: SessionLabels, config: ClassifierConfig) -> ScoreResult {
        var r = ScoreResult()
        var attrCorrect = 0, attrUncertain = 0
        var speechWindows = 0, speechVoiced = 0
        var voicedPreds = 0, voicedPredsNotSilence = 0
        var bothVoiced = 0, bothUncertain = 0
        struct BlockAcc { var correct = 0, attributed = 0, scored = 0; var levelSum = 0.0, floorSum = 0.0 }
        var blockAcc = [BlockAcc](repeating: BlockAcc(), count: labels.blocks.count)
        var blockSeen = [Bool](repeating: false, count: labels.blocks.count)

        for w in windows {
            guard let t = truth(atMs: w.startMs, labels: labels) else { continue }
            blockSeen[t.blockIndex] = true
            if t.isMargin { r.marginWindows += 1; continue }
            r.scoredWindows += 1
            let pred = Prediction(w)
            blockAcc[t.blockIndex].scored += 1
            blockAcc[t.blockIndex].levelSum += w.levelDb
            blockAcc[t.blockIndex].floorSum += w.noiseFloorDb

            switch t.label {
            case .you, .partner:
                r.confusion[t.label.rawValue, default: [:]][pred.rawValue, default: 0] += 1
                speechWindows += 1
                if w.voiced {
                    speechVoiced += 1
                    voicedPreds += 1
                    voicedPredsNotSilence += 1
                    r.attributionWindowCount += 1
                    blockAcc[t.blockIndex].attributed += 1
                    let correct = (t.label == .you && pred == .user) || (t.label == .partner && pred == .room)
                    if correct { attrCorrect += 1; blockAcc[t.blockIndex].correct += 1 }
                    if pred == .uncertain { attrUncertain += 1 }
                }
            case .silence:
                r.confusion["silence", default: [:]][pred.rawValue, default: 0] += 1
                if w.voiced { voicedPreds += 1 }
            case .both:
                if w.voiced {
                    voicedPreds += 1
                    voicedPredsNotSilence += 1
                    bothVoiced += 1
                    if pred == .uncertain { bothUncertain += 1 }
                }
            }
        }

        func ratio(_ n: Int, _ d: Int) -> Double? { d > 0 ? Double(n) / Double(d) : nil }
        r.attributionAccuracy = ratio(attrCorrect, r.attributionWindowCount)
        r.uncertainFraction = ratio(attrUncertain, r.attributionWindowCount)
        r.vadRecall = ratio(speechVoiced, speechWindows)
        r.vadPrecision = ratio(voicedPredsNotSilence, voicedPreds)
        r.bothUncertainFraction = ratio(bothUncertain, bothVoiced)

        for (i, b) in labels.blocks.enumerated() where blockSeen[i] && (b.label == .you || b.label == .partner) {
            let a = blockAcc[i]
            r.perBlock.append(BlockScore(
                label: b.label, startMs: b.startMs, endMs: b.endMs, scoredWindows: a.scored,
                accuracy: ratio(a.correct, a.attributed),
                meanLevelDb: a.scored > 0 ? a.levelSum / Double(a.scored) : 0,
                meanFloorDb: a.scored > 0 ? a.floorSum / Double(a.scored) : 0))
        }
        r.worstBlocks = Array(r.perBlock.sorted { ($0.accuracy ?? -1) < ($1.accuracy ?? -1) }.prefix(3))

        scoreShare(windows: windows, labels: labels, config: config, into: &r)
        return r
    }

    private static func scoreShare(windows: [WindowStat], labels: SessionLabels,
                                   config: ClassifierConfig, into r: inout ScoreResult) {
        var estimator = TalkShareEstimator(config: config)
        var cursor = 0
        var absErrorSum = 0.0, errorCount = 0, uncertainCount = 0
        let spanMs = Int(config.shareWindowSec * 1000)

        for block in labels.blocks {
            if let early = labels.endedEarlyAtMs, block.startMs >= early { break }
            let end = min(block.endMs, labels.endedEarlyAtMs ?? Int.max)
            while cursor < windows.count, windows[cursor].startMs < end {
                estimator.push(windows[cursor])
                cursor += 1
            }
            guard let trueShare = trueShare(endingAtMs: end, spanMs: spanMs, labels: labels) else { continue }
            r.sharePointCount += 1
            switch estimator.share {
            case .uncertain:
                uncertainCount += 1
            case .value(let v):
                absErrorSum += abs(v - trueShare) * 100
                errorCount += 1
            }
        }
        r.shareMeanAbsErrorPoints = errorCount > 0 ? absErrorSum / Double(errorCount) : nil
        r.shareUncertainFraction = r.sharePointCount > 0 ? Double(uncertainCount) / Double(r.sharePointCount) : nil
    }

    /// True wearer share over [end - span, end) from labels; nil if no voiced time in range.
    static func trueShare(endingAtMs end: Int, spanMs: Int, labels: SessionLabels) -> Double? {
        let start = end - spanMs
        var user = 0, room = 0
        for b in labels.blocks {
            let overlap = max(0, min(b.endMs, end) - max(b.startMs, start))
            guard overlap > 0 else { continue }
            switch b.label {
            case .you: user += overlap
            case .partner: room += overlap
            case .both: user += overlap; room += overlap
            case .silence: break
            }
        }
        return user + room > 0 ? Double(user) / Double(user + room) : nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ScorerTests`
Expected: 8 tests pass. If `testIdealPredictionsScorePerfectly` reports 29 attributed windows per block, re-check the margin inequality: `(t - start) < 500` and `(end - t) <= 500`.

- [ ] **Step 5: Commit**

```bash
git add Sources/TwoEarsLabKit/Scorer.swift Tests/TwoEarsLabKitTests/ScorerTests.swift
git commit -m "Add Scorer with margin exclusion, confusion, VAD, per-block, and share error metrics"
```

---

### Task 11: Analyzer, Analysis model, and synthetic fixture

**Files:**
- Create: `Sources/TwoEarsLabKit/Analysis.swift`
- Create: `Sources/TwoEarsLabKit/Analyzer.swift`
- Modify: `Tests/TwoEarsLabKitTests/SyntheticSession.swift`
- Test: `Tests/TwoEarsLabKitTests/AnalyzerTests.swift`

The fixture follows the spec's constraint: in every speech block, one window in ten drops to the noise level so the noise floor stays at the noise level, and the nine voiced windows between dips form 900 ms runs that survive burst rejection. Levels: noise -60 dBFS, `you` tone -20, `partner` tone -50 (6 dB below the user boundary, safely `room`), `both` tone -44 (exactly the boundary, so `uncertain`). Tone frequency 200 Hz gives ZCR 0.025, inside the band.

- [ ] **Step 1: Write the fixture generator**

Replace `Tests/TwoEarsLabKitTests/SyntheticSession.swift`:

```swift
import Foundation
import TwoEarsCore
@testable import TwoEarsLabKit

/// Builds a fake recording that follows a turn script, for end-to-end tests.
enum SyntheticSession {
    static let sampleRate = 16000
    static let noiseDb = -60.0
    static let youDb = -20.0
    static let partnerDb = -50.0
    static let bothDb = -44.0
    static let toneHz = 200.0

    static func sine(dbfs: Double, count: Int, phase: Int) -> [Float] {
        let amplitude = pow(10, dbfs / 20) * 2.0.squareRoot()
        return (0..<count).map { i in
            Float(amplitude * sin(2 * .pi * toneHz * Double(i + phase) / Double(sampleRate)))
        }
    }

    static func noise(dbfs: Double, count: Int, seed: inout UInt64) -> [Float] {
        var raw: [Double] = []
        raw.reserveCapacity(count)
        for _ in 0..<count {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            raw.append(Double(seed >> 11) / Double(1 << 53) * 2 - 1)
        }
        let rms = (raw.reduce(0) { $0 + $1 * $1 } / Double(count)).squareRoot()
        let gain = pow(10, dbfs / 20) / rms
        return raw.map { Float($0 * gain) }
    }

    /// Samples for the whole script. Speech blocks dip to noise on every tenth window.
    static func samples(for script: TurnScript, config: ClassifierConfig = .default) -> [Float] {
        var out: [Float] = []
        var seed: UInt64 = 42
        let n = config.samplesPerWindow
        for block in script.timeline() {
            let windows = block.durationMs / config.windowMs
            for w in 0..<windows {
                let level: Double?
                switch block.label {
                case .silence: level = nil
                case .you: level = youDb
                case .partner: level = partnerDb
                case .both: level = bothDb
                }
                if let level, w % 10 != 9 {
                    out += sine(dbfs: level, count: n, phase: out.count)
                } else {
                    out += noise(dbfs: noiseDb, count: n, seed: &seed)
                }
            }
        }
        return out
    }

    /// Writes audio.wav and labels.json into `dir` and returns the labels.
    @discardableResult
    static func write(script: TurnScript = .default, condition: String = "quiet", device: String = "synthetic",
                      sampleRate: Int = 16000, to dir: URL) throws -> SessionLabels {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try WavFile.write(samples: samples(for: script), sampleRate: SyntheticSession.sampleRate,
                          to: dir.appendingPathComponent(SessionFiles.audioName))
        let labels = SessionLabels(recordedAt: Date(timeIntervalSince1970: 1_800_000_000), condition: condition,
                                   device: device, notes: "synthetic fixture", sampleRate: sampleRate,
                                   scriptName: script.name, blocks: script.timeline(), endedEarlyAtMs: nil)
        try SessionFiles.writeLabels(labels, in: dir)
        return labels
    }
}
```

- [ ] **Step 2: Write the failing tests**

`Tests/TwoEarsLabKitTests/AnalyzerTests.swift`:

```swift
import XCTest
import TwoEarsCore
@testable import TwoEarsLabKit

final class AnalyzerTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tmp)
    }

    func testFixtureScoresAboveGate() throws {
        let dir = tmp.appendingPathComponent("20270115-080000-quiet")
        try SyntheticSession.write(to: dir)
        let a = try Analyzer.analyze(sessionDir: dir)
        XCTAssertGreaterThan(a.score.attributionAccuracy ?? 0, 0.95)
        XCTAssertLessThan(a.score.shareMeanAbsErrorPoints ?? 100, 5)
        XCTAssertEqual(a.score.bothUncertainFraction ?? 0, 1.0, accuracy: 0.05)
        XCTAssertTrue(a.usesDefaultConfig)
        XCTAssertEqual(a.session.condition, "quiet")
        XCTAssertEqual(a.session.sessionDir, "20270115-080000-quiet")
        XCTAssertEqual(a.session.durationMs, 190_000)
        XCTAssertNil(a.sweep)

        let onDisk = try SessionFiles.decoder.decode(Analysis.self,
            from: Data(contentsOf: dir.appendingPathComponent(SessionFiles.analysisName)))
        XCTAssertEqual(onDisk, a)
    }

    func testCustomConfigIsFlagged() throws {
        let dir = tmp.appendingPathComponent("s")
        try SyntheticSession.write(to: dir)
        var c = ClassifierConfig.default
        c.userBandDb = 12
        let a = try Analyzer.analyze(sessionDir: dir, config: c)
        XCTAssertFalse(a.usesDefaultConfig)
        XCTAssertEqual(a.config.userBandDb, 12)
    }

    func testSweepProducesGridWithDefaultCellMatching() throws {
        let dir = tmp.appendingPathComponent("s")
        try SyntheticSession.write(to: dir)
        let a = try Analyzer.analyze(sessionDir: dir, sweep: true)
        let cells = try XCTUnwrap(a.sweep)
        XCTAssertEqual(cells.count, 24)
        let defaultCell = try XCTUnwrap(cells.first { $0.vadMarginDb == 8 && $0.userBandDb == 16 })
        XCTAssertEqual(defaultCell.attributionAccuracy, a.score.attributionAccuracy)
    }

    func testDumpWindowsCsv() throws {
        let dir = tmp.appendingPathComponent("s")
        try SyntheticSession.write(to: dir)
        let csv = tmp.appendingPathComponent("w.csv")
        let a = try Analyzer.analyze(sessionDir: dir, dumpWindowsTo: csv)
        let text = try String(contentsOf: csv, encoding: .utf8)
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.first, "index,startMs,levelDb,noiseFloorDb,zcr,voiced,attribution,truth")
        XCTAssertEqual(lines.count, 1 + a.session.durationMs / 100)
        XCTAssertTrue(lines[1].hasPrefix("0,0,"))
    }

    func testSampleRateMismatchThrows() throws {
        let dir = tmp.appendingPathComponent("s")
        try SyntheticSession.write(sampleRate: 44_100, to: dir)
        XCTAssertThrowsError(try Analyzer.analyze(sessionDir: dir)) { error in
            XCTAssertTrue("\(error)".contains("44100"))
        }
    }

    func testMissingFilesThrow() throws {
        let dir = tmp.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        XCTAssertThrowsError(try Analyzer.analyze(sessionDir: dir))
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter AnalyzerTests`
Expected: compile errors, `Analyzer` and `Analysis` not found.

- [ ] **Step 4: Implement the Analysis model**

`Sources/TwoEarsLabKit/Analysis.swift`:

```swift
import Foundation
import TwoEarsCore

public struct SessionInfo: Codable, Equatable, Sendable {
    public var sessionDir: String
    public var condition: String
    public var device: String
    public var recordedAt: Date
    public var notes: String?
    public var scriptName: String
    public var durationMs: Int

    public init(sessionDir: String, condition: String, device: String, recordedAt: Date,
                notes: String?, scriptName: String, durationMs: Int) {
        self.sessionDir = sessionDir
        self.condition = condition
        self.device = device
        self.recordedAt = recordedAt
        self.notes = notes
        self.scriptName = scriptName
        self.durationMs = durationMs
    }
}

public struct SweepCell: Codable, Equatable, Sendable {
    public var vadMarginDb: Double
    public var userBandDb: Double
    public var attributionAccuracy: Double?
    public var uncertainFraction: Double?
}

/// analysis.json: one session's grade.
public struct Analysis: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var session: SessionInfo
    public var config: ClassifierConfig
    public var usesDefaultConfig: Bool
    public var score: ScoreResult
    public var sweep: [SweepCell]?

    public init(session: SessionInfo, config: ClassifierConfig, score: ScoreResult, sweep: [SweepCell]?) {
        self.session = session
        self.config = config
        self.usesDefaultConfig = config.isDefault
        self.score = score
        self.sweep = sweep
    }
}
```

- [ ] **Step 5: Implement the Analyzer**

`Sources/TwoEarsLabKit/Analyzer.swift`:

```swift
import Foundation
import TwoEarsCore

public enum AnalyzerError: Error, CustomStringConvertible {
    case missingFile(String)
    case sampleRateMismatch(wav: Int, labels: Int, config: Int)

    public var description: String {
        switch self {
        case .missingFile(let p): return "missing file: \(p)"
        case .sampleRateMismatch(let w, let l, let c):
            return "sample rate mismatch: audio.wav \(w) Hz, labels.json \(l) Hz, config \(c) Hz"
        }
    }
}

public enum Analyzer {
    public static let sweepVadMargins: [Double] = [6, 8, 10, 12]
    public static let sweepUserBands: [Double] = [10, 12, 14, 16, 18, 20]
    static let chunkSize = 4096

    /// Runs the pipeline over a whole signal, including finish().
    public static func windows(samples: [Float], config: ClassifierConfig) -> [WindowStat] {
        let p = Pipeline(config: config)
        var out: [WindowStat] = []
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + chunkSize)
            out += p.process(Array(samples[start..<end]))
            start = end
        }
        out += p.finish()
        return out
    }

    @discardableResult
    public static func analyze(sessionDir: URL, config: ClassifierConfig = .default,
                               sweep: Bool = false, dumpWindowsTo: URL? = nil) throws -> Analysis {
        let audioURL = sessionDir.appendingPathComponent(SessionFiles.audioName)
        let labelsURL = sessionDir.appendingPathComponent(SessionFiles.labelsName)
        for url in [audioURL, labelsURL] where !FileManager.default.fileExists(atPath: url.path) {
            throw AnalyzerError.missingFile(url.path)
        }
        let labels = try SessionFiles.readLabels(in: sessionDir)
        let wav = try WavFile.read(audioURL)
        guard wav.sampleRate == labels.sampleRate, wav.sampleRate == config.sampleRate else {
            throw AnalyzerError.sampleRateMismatch(wav: wav.sampleRate, labels: labels.sampleRate, config: config.sampleRate)
        }

        let ws = windows(samples: wav.samples, config: config)
        let score = Scorer.score(windows: ws, labels: labels, config: config)

        var cells: [SweepCell]?
        if sweep {
            cells = []
            for margin in sweepVadMargins {
                for band in sweepUserBands {
                    var c = config
                    c.vadMarginDb = margin
                    c.userBandDb = band
                    let s = Scorer.score(windows: windows(samples: wav.samples, config: c), labels: labels, config: c)
                    cells?.append(SweepCell(vadMarginDb: margin, userBandDb: band,
                                            attributionAccuracy: s.attributionAccuracy,
                                            uncertainFraction: s.uncertainFraction))
                }
            }
        }

        if let csv = dumpWindowsTo {
            try writeWindowsCsv(ws, labels: labels, to: csv)
        }

        let info = SessionInfo(sessionDir: sessionDir.lastPathComponent, condition: labels.condition,
                               device: labels.device, recordedAt: labels.recordedAt, notes: labels.notes,
                               scriptName: labels.scriptName, durationMs: labels.scriptTotalMs)
        let analysis = Analysis(session: info, config: config, score: score, sweep: cells)
        try SessionFiles.encoder.encode(analysis).write(to: sessionDir.appendingPathComponent(SessionFiles.analysisName))
        return analysis
    }

    public static func writeWindowsCsv(_ ws: [WindowStat], labels: SessionLabels, to url: URL) throws {
        var lines = ["index,startMs,levelDb,noiseFloorDb,zcr,voiced,attribution,truth"]
        lines.reserveCapacity(ws.count + 1)
        for w in ws {
            let truth: String
            if let t = Scorer.truth(atMs: w.startMs, labels: labels) {
                truth = t.isMargin ? "margin" : t.label.rawValue
            } else {
                truth = "absent"
            }
            lines.append([
                String(w.index), String(w.startMs),
                String(format: "%.2f", w.levelDb), String(format: "%.2f", w.noiseFloorDb),
                String(format: "%.4f", w.zcr), w.voiced ? "1" : "0",
                w.attribution?.rawValue ?? "", truth,
            ].joined(separator: ","))
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter AnalyzerTests`
Expected: 6 tests pass in roughly 20 seconds; the sweep test runs 24 pipelines over 3 million samples, so it is slow, not hung. If `testFixtureScoresAboveGate` fails on accuracy, run `analyze` with `--dump-windows` equivalent in a scratch test and check whether the noise floor drifted above -60 (dip pattern broken) or partner windows landed in `uncertain` (partner level too close to the boundary).

- [ ] **Step 7: Commit**

```bash
git add Sources/TwoEarsLabKit/Analysis.swift Sources/TwoEarsLabKit/Analyzer.swift Tests/TwoEarsLabKitTests/SyntheticSession.swift Tests/TwoEarsLabKitTests/AnalyzerTests.swift
git commit -m "Add Analyzer with sweep, CSV dump, and synthetic end-to-end fixture"
```

---

### Task 12: Reporter

**Files:**
- Create: `Sources/TwoEarsLabKit/Reporter.swift`
- Test: `Tests/TwoEarsLabKitTests/ReporterTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
import TwoEarsCore
@testable import TwoEarsLabKit

final class ReporterTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tmp)
    }

    private func analysis(_ dir: String, condition: String, accuracy: Double, custom: Bool = false,
                          worst: [BlockScore] = []) -> Analysis {
        var config = ClassifierConfig.default
        if custom { config.userBandDb = 12 }
        var score = ScoreResult()
        score.attributionAccuracy = accuracy
        score.uncertainFraction = 0.1
        score.vadPrecision = 0.9
        score.vadRecall = 0.8
        score.shareMeanAbsErrorPoints = 4
        score.shareUncertainFraction = 0.2
        score.worstBlocks = worst
        let info = SessionInfo(sessionDir: dir, condition: condition, device: "mic",
                               recordedAt: Date(timeIntervalSince1970: 1_800_000_000), notes: nil,
                               scriptName: "default", durationMs: 190_000)
        return Analysis(session: info, config: config, score: score, sweep: nil)
    }

    func testGoWithThreeQuietSessionsAtGate() {
        let v = Reporter.verdict(for: [
            analysis("a", condition: "quiet", accuracy: 0.90),
            analysis("b", condition: "quiet", accuracy: 0.90),
            analysis("c", condition: "quiet", accuracy: 0.85),
            analysis("d", condition: "cafe", accuracy: 0.30),
        ])
        XCTAssertEqual(v.verdict, .go)
        XCTAssertEqual(v.quietSessionCount, 3)
        XCTAssertEqual(v.meanQuietAccuracy!, 0.8833, accuracy: 1e-3)
    }

    func testNoGoBelowGate() {
        let v = Reporter.verdict(for: (0..<3).map { analysis("s\($0)", condition: "quiet", accuracy: 0.80) })
        XCTAssertEqual(v.verdict, .noGo)
    }

    func testInsufficientWithTwoQuietSessions() {
        let v = Reporter.verdict(for: (0..<2).map { analysis("s\($0)", condition: "quiet", accuracy: 0.95) })
        XCTAssertEqual(v.verdict, .insufficientData)
    }

    func testCustomConfigSessionsAreExcludedFromVerdict() {
        let v = Reporter.verdict(for: [
            analysis("a", condition: "quiet", accuracy: 0.95),
            analysis("b", condition: "quiet", accuracy: 0.95),
            analysis("c", condition: "quiet", accuracy: 0.95, custom: true),
        ])
        XCTAssertEqual(v.verdict, .insufficientData)
        XCTAssertEqual(v.quietSessionCount, 2)
    }

    func testMarkdownContent() {
        let worst = [BlockScore(label: .partner, startMs: 25_000, endMs: 45_000, scoredWindows: 190,
                                accuracy: 0.4, meanLevelDb: -38.5, meanFloorDb: -45.2)]
        let md = Reporter.markdown(for: [
            analysis("a", condition: "quiet", accuracy: 0.95),
            analysis("b", condition: "quiet", accuracy: 0.95, custom: true),
            analysis("c", condition: "cafe", accuracy: 0.40, worst: worst),
        ])
        XCTAssertTrue(md.contains("INSUFFICIENT DATA"))
        XCTAssertTrue(md.contains("## quiet"))
        XCTAssertTrue(md.contains("## cafe"))
        XCTAssertTrue(md.contains("custom config"))
        XCTAssertTrue(md.contains("95.0%"))
        XCTAssertTrue(md.contains("## Failure modes"))
        XCTAssertTrue(md.contains("partner 25s-45s"))
        XCTAssertTrue(md.contains("-38.5"))
    }

    func testLoadFindsNestedAnalysesSortedByDate() throws {
        let a = analysis("x", condition: "quiet", accuracy: 0.9)
        var b = analysis("y", condition: "cafe", accuracy: 0.5)
        b.session.recordedAt = Date(timeIntervalSince1970: 1_700_000_000)
        for (name, value) in [("x", a), ("deeper/y", b)] {
            let dir = tmp.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try SessionFiles.encoder.encode(value).write(to: dir.appendingPathComponent(SessionFiles.analysisName))
        }
        let loaded = try Reporter.loadAnalyses(under: tmp)
        XCTAssertEqual(loaded.map(\.session.sessionDir), ["y", "x"])
    }

    func testWriteReportCreatesFile() throws {
        let dir = tmp.appendingPathComponent("s")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try SessionFiles.encoder.encode(analysis("s", condition: "quiet", accuracy: 0.9))
            .write(to: dir.appendingPathComponent(SessionFiles.analysisName))
        let out = tmp.appendingPathComponent("report.md")
        let v = try Reporter.writeReport(under: tmp, to: out)
        XCTAssertEqual(v.verdict, .insufficientData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ReporterTests`
Expected: compile errors.

- [ ] **Step 3: Implement**

`Sources/TwoEarsLabKit/Reporter.swift`:

```swift
import Foundation
import TwoEarsCore

public enum Verdict: String, Sendable {
    case go = "GO"
    case noGo = "NO-GO"
    case insufficientData = "INSUFFICIENT DATA"
}

public struct VerdictResult: Equatable, Sendable {
    public var verdict: Verdict
    public var quietSessionCount: Int
    public var meanQuietAccuracy: Double?
}

public enum Reporter {
    public static let gateAccuracy = 0.85
    public static let minQuietSessions = 3
    public static let quietCondition = "quiet"

    public static func loadAnalyses(under root: URL) throws -> [Analysis] {
        var found: [Analysis] = []
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        for case let url as URL in e where url.lastPathComponent == SessionFiles.analysisName {
            found.append(try SessionFiles.decoder.decode(Analysis.self, from: Data(contentsOf: url)))
        }
        return found.sorted { $0.session.recordedAt < $1.session.recordedAt }
    }

    public static func verdict(for analyses: [Analysis]) -> VerdictResult {
        let gated = analyses.filter { $0.usesDefaultConfig && $0.session.condition == quietCondition }
        let accuracies = gated.compactMap(\.score.attributionAccuracy)
        let mean = accuracies.isEmpty ? nil : accuracies.reduce(0, +) / Double(accuracies.count)
        let verdict: Verdict
        if accuracies.count < minQuietSessions {
            verdict = .insufficientData
        } else {
            verdict = (mean ?? 0) >= gateAccuracy ? .go : .noGo
        }
        return VerdictResult(verdict: verdict, quietSessionCount: accuracies.count, meanQuietAccuracy: mean)
    }

    public static func markdown(for analyses: [Analysis]) -> String {
        let v = verdict(for: analyses)
        var md = "# 2Ears M0 validation report\n\n"
        md += "**Verdict: \(v.verdict.rawValue)**. "
        md += "Gate: mean attribution accuracy >= \(pct(gateAccuracy)) over at least \(minQuietSessions) quiet sessions with the default config. "
        md += "Found \(v.quietSessionCount) qualifying quiet session(s)"
        if let m = v.meanQuietAccuracy { md += " with mean accuracy \(pct(m))" }
        md += ".\n\n"

        let conditions = Array(Set(analyses.map(\.session.condition))).sorted {
            ($0 == quietCondition ? 0 : 1, $0) < ($1 == quietCondition ? 0 : 1, $1)
        }
        for condition in conditions {
            md += "## \(condition)\n\n"
            md += "| Session | Device | Config | Accuracy | Uncertain | VAD precision | VAD recall | Share MAE | Share uncertain |\n"
            md += "| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n"
            for a in analyses where a.session.condition == condition {
                let s = a.score
                md += "| \(a.session.sessionDir) | \(a.session.device) | \(a.usesDefaultConfig ? "default" : "custom config") "
                md += "| \(pct(s.attributionAccuracy)) | \(pct(s.uncertainFraction)) | \(pct(s.vadPrecision)) | \(pct(s.vadRecall)) "
                md += "| \(points(s.shareMeanAbsErrorPoints)) | \(pct(s.shareUncertainFraction)) |\n"
            }
            md += "\n"
        }

        let nonQuiet = analyses.filter { $0.session.condition != quietCondition && !$0.score.worstBlocks.isEmpty }
        if !nonQuiet.isEmpty {
            md += "## Failure modes\n\nWorst-scoring speech blocks outside quiet rooms. Rewrite these into prose for the M0 write-up.\n\n"
            md += "| Session | Block | Accuracy | Mean level dB | Mean floor dB | Level over floor |\n"
            md += "| --- | --- | --- | --- | --- | --- |\n"
            for a in nonQuiet {
                for b in a.score.worstBlocks {
                    md += "| \(a.session.sessionDir) | \(b.label.rawValue) \(b.startMs / 1000)s-\(b.endMs / 1000)s "
                    md += "| \(pct(b.accuracy)) | \(String(format: "%.1f", b.meanLevelDb)) | \(String(format: "%.1f", b.meanFloorDb)) "
                    md += "| \(String(format: "%.1f", b.meanLevelDb - b.meanFloorDb)) |\n"
                }
            }
            md += "\n"
        }
        return md
    }

    @discardableResult
    public static func writeReport(under root: URL, to out: URL) throws -> VerdictResult {
        let analyses = try loadAnalyses(under: root)
        try markdown(for: analyses).write(to: out, atomically: true, encoding: .utf8)
        return verdict(for: analyses)
    }

    static func pct(_ v: Double?) -> String {
        guard let v else { return "n/a" }
        return String(format: "%.1f%%", v * 100)
    }

    static func points(_ v: Double?) -> String {
        guard let v else { return "n/a" }
        return String(format: "%.1f pts", v)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ReporterTests`
Expected: 7 tests pass.

- [ ] **Step 5: Run the full suite and commit**

Run: `swift test`
Expected: every test passes.

```bash
git add Sources/TwoEarsLabKit/Reporter.swift Tests/TwoEarsLabKitTests/ReporterTests.swift
git commit -m "Add Reporter with go/no-go verdict and failure-mode table"
```

---

### Task 13: InputDevices and AudioCapture

**Files:**
- Create: `Sources/TwoEarsLabKit/InputDevices.swift`
- Create: `Sources/TwoEarsLabKit/AudioCapture.swift`

No unit tests: these wrap Core Audio and AVAudioEngine and need real hardware. They are verified by the smoke run in Task 15. Keep every line of logic that can be tested out of these files; they only move samples.

- [ ] **Step 1: Implement device listing**

`Sources/TwoEarsLabKit/InputDevices.swift`:

```swift
import CoreAudio
import Foundation

public struct InputDevice: Equatable, Sendable {
    public let id: AudioDeviceID
    public let name: String
    public let inputChannels: Int
}

/// Core Audio devices that have at least one input channel.
public enum InputDevices {
    public static func list() -> [InputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            let channels = inputChannelCount(id)
            guard channels > 0, let name = name(of: id) else { return nil }
            return InputDevice(id: id, name: name, inputChannels: channels)
        }
    }

    public static func find(named name: String) -> InputDevice? {
        list().first { $0.name == name }
    }

    static func inputChannelCount(_ id: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    static func name(of id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: CFString? = nil
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let name else { return nil }
        return name as String
    }
}
```

- [ ] **Step 2: Implement capture**

`Sources/TwoEarsLabKit/AudioCapture.swift`:

```swift
import AVFoundation
import CoreAudio
import Foundation

public enum CaptureError: Error, CustomStringConvertible {
    case permissionDenied
    case deviceSelectionFailed(OSStatus)
    case converterUnavailable(String)

    public var description: String {
        switch self {
        case .permissionDenied:
            return "microphone access denied. Allow your terminal app under System Settings > Privacy & Security > Microphone, then retry."
        case .deviceSelectionFailed(let s):
            return "could not select input device (OSStatus \(s))"
        case .converterUnavailable(let f):
            return "cannot convert input format to 16 kHz mono: \(f)"
        }
    }
}

/// Captures one input device through AVAudioEngine and accumulates 16 kHz mono Float32 samples in memory.
/// The whole session is held in RAM (about 12 MB for the default 190 s script) and returned by stop().
public final class AudioCapture {
    private let engine = AVAudioEngine()
    private let converter: AVAudioConverter
    private let targetFormat: AVAudioFormat
    private let lock = NSLock()
    private var samples: [Float] = []
    public let hardwareFormatDescription: String

    public init(device: InputDevice, sampleRate: Int) throws {
        let input = engine.inputNode
        guard let unit = input.audioUnit else { throw CaptureError.deviceSelectionFailed(-1) }
        var deviceID = device.id
        let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                          &deviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
        guard status == noErr else { throw CaptureError.deviceSelectionFailed(status) }

        let hardware = input.outputFormat(forBus: 0)
        hardwareFormatDescription = "\(Int(hardware.sampleRate)) Hz, \(hardware.channelCount) ch"
        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate),
                                         channels: 1, interleaved: false),
              hardware.channelCount > 0,
              let converter = AVAudioConverter(from: hardware, to: target)
        else { throw CaptureError.converterUnavailable(hardware.description) }
        self.targetFormat = target
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: hardware) { [weak self] buffer, _ in
            self?.consume(buffer)
        }
    }

    public func start() throws {
        engine.prepare()
        try engine.start()
    }

    /// Stops the engine and returns everything captured so far.
    public func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    public var capturedSampleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return samples.count
    }

    private func consume(_ buffer: AVAudioPCMBuffer) {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let channel = out.floatChannelData else { return }
        let chunk = Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
        lock.lock()
        samples.append(contentsOf: chunk)
        lock.unlock()
    }

    /// Blocks on the system permission prompt when access is undetermined.
    public static func ensureMicrophoneAccess() throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                granted = ok
                semaphore.signal()
            }
            semaphore.wait()
            if !granted { throw CaptureError.permissionDenied }
        default:
            throw CaptureError.permissionDenied
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: succeeds with no warnings about unused results. If `kAudioObjectPropertyElementMain` is unavailable, use `kAudioObjectPropertyElementMaster`.

- [ ] **Step 4: Commit**

```bash
git add Sources/TwoEarsLabKit/InputDevices.swift Sources/TwoEarsLabKit/AudioCapture.swift
git commit -m "Add Core Audio device listing and AVAudioEngine capture to 16 kHz mono"
```

---

### Task 14: CLI commands

**Files:**
- Modify: `Sources/TwoEarsLab/Lab.swift`
- Create: `Sources/TwoEarsLab/DevicesCommand.swift`
- Create: `Sources/TwoEarsLab/RecordCommand.swift`
- Create: `Sources/TwoEarsLab/AnalyzeCommand.swift`
- Create: `Sources/TwoEarsLab/ReportCommand.swift`

- [ ] **Step 1: Root command**

`Sources/TwoEarsLab/Lab.swift`:

```swift
import ArgumentParser
import TwoEarsLabKit

@main
struct Lab: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "twoears-lab",
        abstract: "2Ears M0 validation harness: record labeled samples and grade the loudness classifier.",
        subcommands: [DevicesCommand.self, RecordCommand.self, AnalyzeCommand.self, ReportCommand.self]
    )
}
```

- [ ] **Step 2: devices**

`Sources/TwoEarsLab/DevicesCommand.swift`:

```swift
import ArgumentParser
import TwoEarsLabKit

struct DevicesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "devices", abstract: "List audio input devices.")

    func run() throws {
        let devices = InputDevices.list()
        if devices.isEmpty {
            print("No input devices found.")
            return
        }
        for d in devices {
            print("\(d.name)  (\(d.inputChannels) ch)")
        }
    }
}
```

- [ ] **Step 3: record**

`Sources/TwoEarsLab/RecordCommand.swift`:

```swift
import ArgumentParser
import Foundation
import TwoEarsLabKit

struct RecordCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "Record a scripted, labeled session from an input device.")

    @Option(help: "Room condition tag: quiet, cafe, or any other word.")
    var condition: String

    @Option(help: "Input device name exactly as printed by `devices`.")
    var device: String

    @Option(help: "Path to a turn script JSON. Defaults to the built-in default script.")
    var script: String?

    @Option(help: "Free-text notes, e.g. mic position and partner distance.")
    var notes: String?

    @Option(help: "Directory that receives the session folder.")
    var out: String = "sessions"

    func run() throws {
        let turnScript = try script.map { try TurnScript.load(from: URL(fileURLWithPath: $0)) } ?? .default
        guard let inputDevice = InputDevices.find(named: device) else {
            FileHandle.standardError.write(Data("Unknown device \"\(device)\". Available:\n".utf8))
            for d in InputDevices.list() { FileHandle.standardError.write(Data("  \(d.name)\n".utf8)) }
            throw ExitCode(2)
        }
        do {
            try AudioCapture.ensureMicrophoneAccess()
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            throw ExitCode(3)
        }

        let sampleRate = 16000
        let capture = try AudioCapture(device: inputDevice, sampleRate: sampleRate)
        let timeline = turnScript.timeline()
        print("Device: \(inputDevice.name) (\(capture.hardwareFormatDescription)), script: \(turnScript.name), \(turnScript.totalMs / 1000) s")

        for n in stride(from: 3, through: 1, by: -1) {
            print("Starting in \(n)...")
            Thread.sleep(forTimeInterval: 1)
        }

        let interrupt = InterruptFlag()
        let startedAt = Date()
        try capture.start()

        var endedEarlyAtMs: Int?
        blocks: for (i, block) in timeline.enumerated() {
            let next = i + 1 < timeline.count ? timeline[i + 1].label : nil
            while true {
                let nowMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                if interrupt.isSet {
                    endedEarlyAtMs = nowMs
                    break blocks
                }
                if nowMs >= block.endMs { break }
                Prompt.render(block: block, remainingSec: (block.endMs - nowMs + 999) / 1000, next: next)
                Thread.sleep(forTimeInterval: 0.25)
            }
        }

        let samples = capture.stop()
        Prompt.clear()

        let dir = URL(fileURLWithPath: out)
            .appendingPathComponent(SessionFiles.directoryName(recordedAt: startedAt, condition: condition))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try WavFile.write(samples: samples, sampleRate: sampleRate, to: dir.appendingPathComponent(SessionFiles.audioName))
        let labels = SessionLabels(recordedAt: startedAt, condition: condition, device: inputDevice.name,
                                   notes: notes, sampleRate: sampleRate, scriptName: turnScript.name,
                                   blocks: timeline, endedEarlyAtMs: endedEarlyAtMs)
        try SessionFiles.writeLabels(labels, in: dir)

        let seconds = Double(samples.count) / Double(sampleRate)
        print("Saved \(dir.path)")
        print(String(format: "Captured %.1f s of audio", seconds) + (endedEarlyAtMs.map { " (stopped early at \($0 / 1000) s)" } ?? ""))
        print("Next: swift run twoears-lab analyze \"\(dir.path)\"")
    }
}

/// Set from a SIGINT handler on a background queue; polled by the prompt loop.
final class InterruptFlag {
    private let lock = NSLock()
    private var flag = false
    private let source: DispatchSourceSignal

    init() {
        signal(SIGINT, SIG_IGN)
        source = DispatchSource.makeSignalSource(signal: SIGINT, queue: DispatchQueue(label: "twoears.sigint"))
        source.setEventHandler { [weak self] in self?.set() }
        source.resume()
    }

    private func set() {
        lock.lock()
        flag = true
        lock.unlock()
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return flag
    }
}

enum Prompt {
    static func clear() {
        print("\u{1B}[2J\u{1B}[H", terminator: "")
    }

    static func render(block: LabelBlock, remainingSec: Int, next: TurnLabel?) {
        clear()
        let title: String
        switch block.label {
        case .you: title = "YOU speak"
        case .partner: title = "PARTNER speaks"
        case .both: title = "BOTH speak"
        case .silence: title = "SILENCE"
        }
        print("==========================================")
        print()
        print("   \(title)")
        print()
        print("   \(remainingSec) s left")
        print()
        print("   next: \(next.map { $0.rawValue.uppercased() } ?? "end of script")")
        print()
        print("==========================================")
        print("Ctrl-C stops early and keeps what was recorded.")
        fflush(stdout)
    }
}
```

- [ ] **Step 4: analyze and report**

`Sources/TwoEarsLab/AnalyzeCommand.swift`:

```swift
import ArgumentParser
import Foundation
import TwoEarsCore
import TwoEarsLabKit

struct AnalyzeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Score one session directory and write analysis.json beside it.")

    @Argument(help: "Session directory containing audio.wav and labels.json.")
    var sessionDir: String

    @Option(help: "JSON file with ClassifierConfig overrides; unnamed keys keep spec defaults.")
    var config: String?

    @Flag(help: "Also grade a grid of VAD margins and user bands.")
    var sweep = false

    @Option(help: "Write per-window levels and decisions to this CSV.")
    var dumpWindows: String?

    func run() throws {
        var classifierConfig = ClassifierConfig.default
        if let path = config {
            classifierConfig = try JSONDecoder().decode(ClassifierConfig.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        }
        let dir = URL(fileURLWithPath: sessionDir)
        let analysis: Analysis
        do {
            analysis = try Analyzer.analyze(sessionDir: dir, config: classifierConfig, sweep: sweep,
                                            dumpWindowsTo: dumpWindows.map { URL(fileURLWithPath: $0) })
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            throw ExitCode(1)
        }
        let s = analysis.score
        print("Session \(analysis.session.sessionDir) [\(analysis.session.condition)] on \(analysis.session.device)")
        print("Config: \(analysis.usesDefaultConfig ? "default" : "custom")")
        print("Attribution accuracy: \(fmt(s.attributionAccuracy)) over \(s.attributionWindowCount) voiced windows")
        print("Uncertain fraction:   \(fmt(s.uncertainFraction))")
        print("VAD precision/recall: \(fmt(s.vadPrecision)) / \(fmt(s.vadRecall))")
        print("Share error:          \(s.shareMeanAbsErrorPoints.map { String(format: "%.1f pts", $0) } ?? "n/a"), uncertain \(fmt(s.shareUncertainFraction)) of \(s.sharePointCount) points")
        if !s.worstBlocks.isEmpty {
            print("Worst blocks:")
            for b in s.worstBlocks {
                print(String(format: "  %@ %ds-%ds  accuracy %@  level %.1f dB  floor %.1f dB",
                             b.label.rawValue, b.startMs / 1000, b.endMs / 1000, fmt(b.accuracy), b.meanLevelDb, b.meanFloorDb))
            }
        }
        if let cells = analysis.sweep {
            print("Sweep (accuracy / uncertain):")
            print("  vad\\band " + Analyzer.sweepUserBands.map { String(format: "%6.0f", $0) }.joined())
            for margin in Analyzer.sweepVadMargins {
                let row = Analyzer.sweepUserBands.map { band -> String in
                    let c = cells.first { $0.vadMarginDb == margin && $0.userBandDb == band }
                    let text = (c?.attributionAccuracy).map { String(format: "%.0f%%", $0 * 100) } ?? "n/a"
                    return String(repeating: " ", count: max(0, 6 - text.count)) + text
                }
                print(String(format: "  %8.0f ", margin) + row.joined())
            }
        }
        print("Wrote \(dir.appendingPathComponent(SessionFiles.analysisName).path)")
    }

    private func fmt(_ v: Double?) -> String {
        v.map { String(format: "%.1f%%", $0 * 100) } ?? "n/a"
    }
}
```

`Sources/TwoEarsLab/ReportCommand.swift`:

```swift
import ArgumentParser
import Foundation
import TwoEarsLabKit

struct ReportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "report",
        abstract: "Aggregate every analysis.json under a directory into report.md with a go/no-go verdict.")

    @Argument(help: "Root directory to search.")
    var root: String = "sessions"

    @Option(help: "Output markdown path.")
    var out: String = "report.md"

    func run() throws {
        let v = try Reporter.writeReport(under: URL(fileURLWithPath: root), to: URL(fileURLWithPath: out))
        print("Verdict: \(v.verdict.rawValue) (\(v.quietSessionCount) quiet sessions"
              + (v.meanQuietAccuracy.map { String(format: ", mean accuracy %.1f%%", $0 * 100) } ?? "") + ")")
        print("Wrote \(out)")
    }
}
```

- [ ] **Step 5: Build and check help**

Run: `swift build && swift run twoears-lab --help && swift run twoears-lab record --help`
Expected: four subcommands listed; record shows condition, device, script, notes, out.

- [ ] **Step 6: Commit**

```bash
git add Sources/TwoEarsLab
git commit -m "Add devices, record, analyze, and report CLI commands"
```

---

### Task 15: Smoke run and wrap-up

**Files:**
- Create: `Scripts/smoke.json`
- Modify: `README.md`

- [ ] **Step 1: Add a 12-second smoke script**

`Scripts/smoke.json`:

```json
{
  "name": "smoke",
  "blocks": [
    { "label": "silence", "seconds": 2 },
    { "label": "you", "seconds": 4 },
    { "label": "partner", "seconds": 4 },
    { "label": "silence", "seconds": 2 }
  ]
}
```

- [ ] **Step 2: Confirm the suite is green before touching hardware**

Run: `swift test`
Expected: all tests pass. The synthetic fixture already proves analyze and report end to end; the steps below prove capture.

- [ ] **Step 3: Record a real smoke session**

Run: `swift run twoears-lab devices`
Expected: at least the built-in microphone is listed. Copy its exact name.

Run (replace the device name):
```bash
swift run twoears-lab record --condition quiet --device "MacBook Pro Microphone" --script Scripts/smoke.json --notes "smoke test at desk"
```
Speak during YOU, stay quiet during PARTNER. The first run triggers the macOS microphone prompt for the terminal application; allow it.
Expected: prompts cycle SILENCE, YOU, PARTNER, SILENCE; a `sessions/<timestamp>-quiet/` folder with `audio.wav` around 12 s and `labels.json`.

- [ ] **Step 4: Analyze and report the smoke session**

```bash
swift run twoears-lab analyze sessions/<dir> --sweep --dump-windows sessions/<dir>/windows.csv
swift run twoears-lab report sessions --out sessions/report.md
```
Expected: analyze prints accuracy, uncertain fraction, VAD numbers, and the sweep table; report prints INSUFFICIENT DATA with 1 quiet session and writes `sessions/report.md`.

- [ ] **Step 5: Test Ctrl-C**

Start another smoke recording and press Ctrl-C during YOU.
Expected: the session is saved, `labels.json` has a non-null `endedEarlyAtMs`, and `analyze` still runs on it.

- [ ] **Step 6: Finish the README**

Append to `README.md`:

```markdown
## Recording protocol

- Put the microphone where the watch would be: on the wearer's wrist or held at forearm
  distance (40-70 cm from the mouth). With an iPhone via Continuity, pick it in `devices`.
- Partner sits 1-2 m away and reads the same screen.
- Follow the prompts. YOU: wearer talks, partner silent. PARTNER: reverse. BOTH: talk over
  each other. SILENCE: nobody talks.
- Record at least three `quiet` sessions and two `cafe` sessions before trusting the verdict.
- Ctrl-C keeps what was recorded and marks the session as ended early.
- Talk the way people talk: sentences with breaths between them. The noise floor is the
  10th percentile of the last 10 seconds, so a speaker who never pauses for more than 10 s
  drags the floor up to their own level and the detector goes quiet. That is a real property
  of the spec's classifier and one of the things M0 is meant to surface, not a harness bug.

## Output

- `sessions/<timestamp>-<condition>/audio.wav` and `labels.json` from `record`.
- `analysis.json` beside them from `analyze`; `--sweep` adds a threshold grid,
  `--dump-windows` writes per-window levels for plotting.
- `report.md` from `report`: GO if mean attribution accuracy over at least three quiet
  sessions with the default config is at or above 85%.
```

- [ ] **Step 7: Full test run and final commit**

Run: `swift test`
Expected: all tests pass.

```bash
git add Scripts/smoke.json README.md
git commit -m "Add smoke script and recording protocol to README"
```

---

## Done when

- `swift test` is green on this Mac.
- `twoears-lab record` has produced a real session from at least one input device and `analyze` graded it.
- `report` writes a verdict file.
- The remaining M0 work, recording three quiet and two cafe sessions and writing the failure-mode prose, is the user's.
