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
