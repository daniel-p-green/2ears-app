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
