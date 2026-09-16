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
