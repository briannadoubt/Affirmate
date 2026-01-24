#if os(macOS)
import Containerization
import ContainerizationExtras
import ContainerizationOCI
import ContainerizationOS
import Foundation
import Logging
import Vapor

public enum ContainerBootstrapError: Error, LocalizedError {
    case containerizationDisabled
    case missingKernelPath
    case invalidKernelPath(String)
    case invalidNumericValue(String, String)
    case invalidMountFormat(String)

    public var errorDescription: String? {
        switch self {
        case .containerizationDisabled:
            return "Containerization bootstrap not enabled."
        case .missingKernelPath:
            return "AFFIRMATE_CONTAINER_KERNEL must be set to the Linux kernel image to boot the virtual machine."
        case .invalidKernelPath(let path):
            return "Kernel not found at \(path)."
        case .invalidNumericValue(let raw, let key):
            return "Unable to parse numeric value '\(raw)' for \(key)."
        case .invalidMountFormat(let value):
            return "Mount entry '\(value)' must be formatted as hostPath:containerPath[:options]."
        }
    }
}

public struct ContainerizedServerConfiguration: Sendable {
    struct MountSpec: Sendable {
        let hostPath: String
        let containerPath: String
        let options: [String]

        init(hostPath: String, containerPath: String, options: [String]) {
            let expanded = (hostPath as NSString).expandingTildeInPath
            self.hostPath = URL(fileURLWithPath: expanded).standardizedFileURL.path(percentEncoded: false)
            self.containerPath = containerPath.hasPrefix("/") ? containerPath : "/" + containerPath
            self.options = options
        }

        func asMount() -> Containerization.Mount {
            Containerization.Mount.share(
                source: hostPath,
                destination: containerPath,
                options: options
            )
        }
    }

    let id: String
    let imageReference: String
    let initfsReference: String
    let kernel: Kernel
    let rootfsSizeInBytes: UInt64
    let cpus: Int
    let memoryInBytes: UInt64
    let mounts: [MountSpec]
    let command: [String]
    let environment: [String]
    let workingDirectory: String
    let hostname: String
    let rosetta: Bool
    let nestedVirtualization: Bool
    let vmnetSubnet: String?
    let ipAddress: String?
    let gateway: String?
    let nameservers: [String]
    let stateDirectory: URL?

    public static func load(defaultRepositoryRoot: String) throws -> ContainerizedServerConfiguration? {
        guard ProcessInfo.processInfo.environment.truthy("AFFIRMATE_CONTAINERIZE") else {
            return nil
        }

        let env = ProcessInfo.processInfo.environment

        guard let kernelPath = env["AFFIRMATE_CONTAINER_KERNEL"] else {
            throw ContainerBootstrapError.missingKernelPath
        }

        let kernelURL = URL(fileURLWithPath: kernelPath)
        guard FileManager.default.fileExists(atPath: kernelURL.path) else {
            throw ContainerBootstrapError.invalidKernelPath(kernelURL.path)
        }

        let kernel = Kernel(path: kernelURL, platform: .linuxArm)

        let rawIdentifier = env["AFFIRMATE_CONTAINER_ID"].flatMap { $0.isEmpty ? nil : $0 }
        let identifier = rawIdentifier ?? "affirmate-server"

        let image = env["AFFIRMATE_CONTAINER_IMAGE"] ?? "docker.io/library/swift:6.0-jammy"
        let initfs = env["AFFIRMATE_CONTAINER_INITFS"] ?? "vminit:latest"

        let rootfsSize = try parseMegabytes(env["AFFIRMATE_CONTAINER_ROOTFS_MB"], key: "AFFIRMATE_CONTAINER_ROOTFS_MB", defaultValue: 4096)
        let cpuCount = try parseInteger(env["AFFIRMATE_CONTAINER_CPUS"], key: "AFFIRMATE_CONTAINER_CPUS", defaultValue: 4)
        let memorySize = try parseMegabytes(env["AFFIRMATE_CONTAINER_MEMORY_MB"], key: "AFFIRMATE_CONTAINER_MEMORY_MB", defaultValue: 4096)

        let projectRoot = env["AFFIRMATE_CONTAINER_PROJECT_ROOT"] ?? defaultRepositoryRoot
        let defaultMounts = [MountSpec(hostPath: projectRoot, containerPath: "/workspace", options: [])]
        let parsedMounts = try parseMounts(env["AFFIRMATE_CONTAINER_MOUNTS"], defaults: defaultMounts)

        let containerWorkdir = env["AFFIRMATE_CONTAINER_WORKDIR"] ?? "/workspace/AffirmateServer"
        let commandString = env["AFFIRMATE_CONTAINER_COMMAND"] ?? "swift run --configuration release Run serve --hostname 0.0.0.0 --port 8080"
        let command = ["/bin/sh", "-lc", "cd \(containerWorkdir.escapingSpaces()) && \(commandString)"]

        let extraEnvironment = parseKeyValueList(env["AFFIRMATE_CONTAINER_ENV"])
        let environment = ["PATH=\(LinuxProcessConfiguration.defaultPath)"] + extraEnvironment

        let hostname = env["AFFIRMATE_CONTAINER_HOSTNAME"] ?? identifier
        let rosetta = env.truthy("AFFIRMATE_CONTAINER_ROSETTA")
        let nested = env.truthy("AFFIRMATE_CONTAINER_NESTED_VIRT")

        let subnet = env["AFFIRMATE_CONTAINER_VMNET_SUBNET"]
        let ipAddress = env["AFFIRMATE_CONTAINER_IP"]
        let gateway = env["AFFIRMATE_CONTAINER_GATEWAY"]
        let nameservers = parseList(env["AFFIRMATE_CONTAINER_NAMESERVERS"], separator: ",")

        let stateRootPath = env["AFFIRMATE_CONTAINER_STATE_ROOT"] ?? Self.defaultStateRoot().path
        let stateDirectory = URL(fileURLWithPath: stateRootPath, isDirectory: true)

        return ContainerizedServerConfiguration(
            id: identifier,
            imageReference: image,
            initfsReference: initfs,
            kernel: kernel,
            rootfsSizeInBytes: rootfsSize,
            cpus: cpuCount,
            memoryInBytes: memorySize,
            mounts: parsedMounts,
            command: command,
            environment: environment,
            workingDirectory: containerWorkdir,
            hostname: hostname,
            rosetta: rosetta,
            nestedVirtualization: nested,
            vmnetSubnet: subnet,
            ipAddress: ipAddress,
            gateway: gateway,
            nameservers: nameservers,
            stateDirectory: stateDirectory
        )
    }

    private static func parseMounts(_ raw: String?, defaults: [MountSpec]) throws -> [MountSpec] {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaults
        }

        let entries = raw.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return try entries.map { entry in
            let parts = entry.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count >= 2 else {
                throw ContainerBootstrapError.invalidMountFormat(entry)
            }

            let host = String(parts[0])
            let guest = String(parts[1])
            let options = parts.count == 3 ? parts[2].split(separator: ",").map { String($0) } : []

            return MountSpec(hostPath: host, containerPath: guest, options: options)
        }
    }

    private static func parseKeyValueList(_ raw: String?) -> [String] {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return raw.split(separator: ";").compactMap { pair -> String? in
            let trimmed = pair.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.contains("=") else { return nil }
            return trimmed
        }
    }

    private static func parseList(_ raw: String?, separator: Character) -> [String] {
        guard let raw else { return [] }
        return raw
            .split(separator: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseMegabytes(_ raw: String?, key: String, defaultValue: UInt64) throws -> UInt64 {
        guard let raw, !raw.isEmpty else {
            return defaultValue * 1_048_576
        }
        guard let value = UInt64(raw) else {
            throw ContainerBootstrapError.invalidNumericValue(raw, key)
        }
        return value * 1_048_576
    }

    private static func parseInteger(_ raw: String?, key: String, defaultValue: Int) throws -> Int {
        guard let raw, !raw.isEmpty else {
            return defaultValue
        }
        guard let value = Int(raw) else {
            throw ContainerBootstrapError.invalidNumericValue(raw, key)
        }
        return value
    }

    private static func defaultStateRoot() -> URL {
        let supportDirectory = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("Affirmate")
            .appendingPathComponent("ContainerRuntime")
        return supportDirectory
    }
}

public actor ContainerizedServerService {
    private let configuration: ContainerizedServerConfiguration
    private let logger: Logger
    private var manager: ContainerManager?
    private var container: LinuxContainer?

    public init(configuration: ContainerizedServerConfiguration, logger: Logger) {
        self.configuration = configuration
        self.logger = logger
    }

    public func start() async throws {
        guard container == nil else {
            logger.info("Container \(configuration.id) already running")
            return
        }

        logger.info("Starting container \(configuration.id) using image \(configuration.imageReference)")

        let network = try await createNetwork()

        var managerInstance = try await ContainerManager(
            kernel: configuration.kernel,
            initfsReference: configuration.initfsReference,
            root: configuration.stateDirectory,
            network: network,
            rosetta: configuration.rosetta,
            nestedVirtualization: configuration.nestedVirtualization
        )

        let configSnapshot = configuration
        let stdoutWriter = LoggerWriter(logger: logger, level: .info)
        let stderrWriter = LoggerWriter(logger: logger, level: .error)

        let containerInstance = try await managerInstance.create(
            configSnapshot.id,
            reference: configSnapshot.imageReference,
            rootfsSizeInBytes: configSnapshot.rootfsSizeInBytes
        ) { config in
            config.cpus = configSnapshot.cpus
            config.memoryInBytes = configSnapshot.memoryInBytes
            config.hostname = configSnapshot.hostname
            config.process.arguments = configSnapshot.command
            config.process.workingDirectory = configSnapshot.workingDirectory
            config.process.environmentVariables = configSnapshot.environment
            config.process.stdout = stdoutWriter
            config.process.stderr = stderrWriter
            config.mounts.append(contentsOf: configSnapshot.mounts.map { $0.asMount() })

            if let ip = configSnapshot.ipAddress, let cidr = try? CIDRv4(ip) {
                let gateway = configSnapshot.gateway.flatMap { try? IPv4Address($0) }
                let interface = NATInterface(ipv4Address: cidr, ipv4Gateway: gateway)
                config.interfaces.append(interface)
            }

            if !configSnapshot.nameservers.isEmpty {
                config.dns = DNS(nameservers: configSnapshot.nameservers)
            }
        }

        try await containerInstance.create()
        try await containerInstance.start()

        manager = managerInstance
        container = containerInstance

        logger.info("Container \(configuration.id) is running")
    }

    public func waitUntilExit() async throws {
        guard let container else {
            logger.warning("waitUntilExit called before container started")
            return
        }

        logger.info("Waiting for container \(configuration.id) to exit")
        try await container.wait()
        logger.info("Container \(configuration.id) exited")
    }

    public func shutdown() async {
        if let container {
            do {
                try await container.stop()
            } catch {
                logger.error("Failed to stop container \(configuration.id): \(error)")
            }
            self.container = nil
        }

        if var manager {
            do {
                try manager.delete(configuration.id)
                self.manager = manager
            } catch {
                logger.error("Failed to delete container state for \(configuration.id): \(error)")
            }
        }
    }

    private func createNetwork() async throws -> (any ContainerManager.Network)? {
        guard let subnetString = configuration.vmnetSubnet else { return nil }
        if #available(macOS 15.0, *) {
            let subnet = try CIDRv4(subnetString)
            return try ContainerManager.VmnetNetwork(subnet: subnet)
        } else {
            logger.warning("vmnet networking requested but unavailable on this macOS version")
            return nil
        }
    }
}

private struct LoggerWriter: Writer, Sendable {
    let logger: Logger
    let level: Logger.Level

    func write(_ data: Data) throws {
        guard !data.isEmpty else { return }
        if let message = String(data: data, encoding: .utf8) {
            message.split(whereSeparator: \.isNewline).forEach { segment in
                if !segment.isEmpty {
                    logger.log(level: level, "[container] \(segment)")
                }
            }
        } else {
            logger.log(level: level, "[container] <binary data size=\(data.count)>")
        }
    }

    func close() throws {}
}

private extension Dictionary where Key == String, Value == String {
    func truthy(_ key: String) -> Bool {
        guard let value = self[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return ["1", "true", "yes", "y", "on"].contains(value)
    }
}

private extension String {
    func escapingSpaces() -> String {
        replacingOccurrences(of: " ", with: "\\ ")
    }
}
#endif
