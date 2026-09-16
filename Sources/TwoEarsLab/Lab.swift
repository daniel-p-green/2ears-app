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
