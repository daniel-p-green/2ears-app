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
