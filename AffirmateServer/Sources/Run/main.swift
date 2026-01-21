import AffirmateServer
import Dispatch
import Foundation
import Logging
import Vapor

// Top-level entry point to avoid using @main in a module that has other top-level code.
func main() async throws {
    try await execute()
}

private func execute() async throws {
    if let containerConfig = try ContainerizedServerConfiguration.load(defaultRepositoryRoot: defaultRepositoryRoot()) {
        let logger = Logger(label: "org.affirmate.container")
        let service = ContainerizedServerService(configuration: containerConfig, logger: logger)
        do {
            try await service.start()
            try await service.waitUntilExit()
        } catch {
            await service.shutdown()
            throw error
        }
        await service.shutdown()
        return
    }

    var env = try Environment.detect()
    try LoggingSystem.bootstrap(from: &env)
    let app = try await Application.make(env)
    defer { Task { try await app.asyncShutdown() } }
    try await configure(app)
    try await app.execute()
}

private func defaultRepositoryRoot() -> String {
    let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    if cwdURL.lastPathComponent == "AffirmateServer" {
        return cwdURL.deletingLastPathComponent().path(percentEncoded: false)
    }
    return cwdURL.path(percentEncoded: false)
}

// Invoke main and crash on failure to match previous behavior of throwing from entry point.
do {
    try await main()
} catch {
    // Print a readable error and exit with failure
    fputs("Error: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
