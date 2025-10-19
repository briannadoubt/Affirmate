//
//  ConfigureTests.swift
//  AffirmateServerTests
//
//  Created by Bri on 10/18/22.
//

import XCTest
import Vapor
@testable import AffirmateServer

#if os(Linux)
import Glibc
#else
import Darwin
#endif

private enum APNSTestCredentials {
    static let keyIdentifier = "TESTKEY123"
    static let teamIdentifier = "TEAMID1234"
    static let privateKeyPEM = """-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIEdwjuRC2nlZ9xtv0mdmQJ3+ylwm46lJL52gy/I7gEKKoAoGCCqGSM49
AwEHoUQDQgAEQevmuqaXzOK/qfBQiTFi+hsix4GosyNmJ0LbVj2yHusbger6ldg8
9dcWtcuG4fVlRmGGwN1DPj0un/kvcnQruw==
-----END EC PRIVATE KEY-----"""
}

private func withAPNSTestEnvironment(_ body: () throws -> Void) rethrows {
    try withEnvironmentVariable(key: "APNS_KEY", value: APNSTestCredentials.privateKeyPEM.replacingOccurrences(of: "\n", with: "\\n")) {
        try withEnvironmentVariable(key: "APNS_KEY_ID", value: APNSTestCredentials.keyIdentifier) {
            try withEnvironmentVariable(key: "APNS_TEAM_ID", value: APNSTestCredentials.teamIdentifier) {
                try body()
            }
        }
    }
}

private func withEnvironmentVariable(key: String, value: String, _ body: () throws -> Void) rethrows {
    let previousValue = getenv(key).flatMap { String(cString: $0) }
    setenv(key, value, 1)
    defer {
        if let previousValue {
            setenv(key, previousValue, 1)
        } else {
            unsetenv(key)
        }
    }
    try body()
}

class ConfigureTests: XCTestCase {
    func testAPNsEnvironmentUsesProductionForProductionApp() {
        XCTAssertEqual(apnsEnvironment(for: .production), .production)
    }

    func testAPNsEnvironmentUsesSandboxForNonProductionApps() {
        XCTAssertEqual(apnsEnvironment(for: .testing), .sandbox)
        XCTAssertEqual(apnsEnvironment(for: .development), .sandbox)
    }

    func testConfigureSetsProductionAPNsEnvironmentForProductionApp() throws {
        try withAPNSTestEnvironment {
            let app = Application(.production)
            defer { app.shutdown() }

            try configure(app)

            XCTAssertEqual(app.apns.configuration?.environment, .production)
        }
    }

    func testConfigureSetsSandboxAPNsEnvironmentForNonProductionApp() throws {
        try withAPNSTestEnvironment {
            let app = Application(.testing)
            defer { app.shutdown() }

            try configure(app)

            XCTAssertEqual(app.apns.configuration?.environment, .sandbox)
        }
    }
}
