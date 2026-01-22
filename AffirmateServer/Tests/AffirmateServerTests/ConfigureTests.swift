//
//  ConfigureTests.swift
//  AffirmateServerTests
//
//  Created by Bri on 10/18/22.
//

import XCTest
import Vapor
import APNS
import APNSCore
@testable import AffirmateServer

#if os(Linux)
import Glibc
#else
import Darwin
#endif

private enum APNSTestCredentials {
    static let keyIdentifier = "TESTKEY123"
    static let teamIdentifier = "TEAMID1234"
    static let privateKeyPEM = """
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIEdwjuRC2nlZ9xtv0mdmQJ3+ylwm46lJL52gy/I7gEKKoAoGCCqGSM49
AwEHoUQDQgAEQevmuqaXzOK/qfBQiTFi+hsix4GosyNmJ0LbVj2yHusbger6ldg8
9dcWtcuG4fVlRmGGwN1DPj0un/kvcnQruw==
-----END EC PRIVATE KEY-----
"""
}

private func withAPNSTestEnvironment<T>(_ body: () async throws -> T) async rethrows -> T {
    try await withEnvironmentVariable(key: "APNS_KEY", value: APNSTestCredentials.privateKeyPEM.replacingOccurrences(of: "\n", with: "\\n")) {
        try await withEnvironmentVariable(key: "APNS_KEY_ID", value: APNSTestCredentials.keyIdentifier) {
            try await withEnvironmentVariable(key: "APNS_TEAM_ID", value: APNSTestCredentials.teamIdentifier) {
                try await body()
            }
        }
    }
}

private func withEnvironmentVariable<T>(key: String, value: String, _ body: () async throws -> T) async rethrows -> T {
    let previousValue = getenv(key).flatMap { String(cString: $0) }
    setenv(key, value, 1)
    defer {
        if let previousValue {
            setenv(key, previousValue, 1)
        } else {
            unsetenv(key)
        }
    }
    return try await body()
}

class ConfigureTests: XCTestCase {
    func testAPNsEnvironmentUsesProductionForProductionApp() {
        XCTAssertEqual(apnsEnvironment(for: .production).url, APNSEnvironment.production.url)
    }

    func testAPNsEnvironmentUsesDevelopmentForNonProductionApps() {
        XCTAssertEqual(apnsEnvironment(for: .testing).url, APNSEnvironment.development.url)
        XCTAssertEqual(apnsEnvironment(for: .development).url, APNSEnvironment.development.url)
    }

    func testConfigureSetsProductionAPNsEnvironmentForProductionApp() async throws {
        try await withAPNSTestEnvironment {
            let app = try await Application.makeTestApplication(.production)
            defer { Task { await app.shutdownTestApplication() } }

            try await configure(app)

            let container = await app.apns.containers.container(for: .production)
            XCTAssertEqual(container?.configuration.environment.url, APNSEnvironment.production.url)
        }
    }

    func testConfigureSetsSandboxAPNsEnvironmentForNonProductionApp() async throws {
        try await withAPNSTestEnvironment {
            let app = try await Application.makeTestApplication(.testing)
            defer { Task { await app.shutdownTestApplication() } }

            try await configure(app)

            let defaultContainer = await app.apns.containers.container()
            XCTAssertEqual(defaultContainer?.configuration.environment.url, APNSEnvironment.development.url)
        }
    }
}
