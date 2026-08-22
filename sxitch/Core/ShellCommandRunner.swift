import Foundation

enum ShellCommandRunner {
    static func run(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", trimmed]

            var environment = ProcessInfo.processInfo.environment
            let homebrewPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
            let currentPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            let missing = homebrewPaths.filter { !currentPath.contains($0) }
            if !missing.isEmpty {
                environment["PATH"] = (missing + [currentPath]).joined(separator: ":")
            }
            process.environment = environment

            process.standardOutput = FileHandle.nullDevice
            let stderrPipe = Pipe()
            process.standardError = stderrPipe

            do {
                try process.run()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    let output = String(decoding: stderrData, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    print(
                        "sxitch shell command failed (\(process.terminationStatus)): \(trimmed)"
                    )
                    if !output.isEmpty {
                        print("stderr: \(output)")
                    }
                }
            } catch {
                print("sxitch shell command could not start: \(error.localizedDescription)")
            }
        }
    }
}
