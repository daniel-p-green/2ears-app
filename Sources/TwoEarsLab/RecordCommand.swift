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
