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
