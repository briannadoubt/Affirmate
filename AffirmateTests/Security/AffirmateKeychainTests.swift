//
//  AffirmateKeychainTests.swift
//  AffirmateTests
//
//  Created by Bri on 10/21/22.
//

#if os(watchOS)
@testable import AffirmateWatch
#else
@testable import Affirmate
#endif
import XCTest

final class AffirmateKeychainTests: XCTestCase {
    
    func test_appIdentifierPrefix() {
        let expected = (Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String) ?? ""
        XCTAssertEqual(AffirmateKeychain.appIdentifierPrefix, expected)
    }
    
    func test_chatService() {
        let expected = "\(AffirmateKeychain.appIdentifierPrefix)org.affirmate.chat"
        XCTAssertEqual(AffirmateKeychain.chatService, expected)
    }
    
    func test_sessionService() {
        let expected = "\(AffirmateKeychain.appIdentifierPrefix)org.affirmate.session"
        XCTAssertEqual(AffirmateKeychain.sessionService, expected)
    }
    
    func test_accessGroup() {
        XCTAssertEqual(AffirmateKeychain.accessGroup, "group.Affirmate")
    }

    func test_chat() throws {
        XCTAssertEqual(AffirmateKeychain.chat.service, "\(AffirmateKeychain.appIdentifierPrefix)org.affirmate.chat")
        XCTAssertEqual(AffirmateKeychain.chat.accessGroup, "group.Affirmate")
        XCTAssertTrue(AffirmateKeychain.chat.synchronizable)
    }
    
    func test_session() throws {
        XCTAssertEqual(AffirmateKeychain.session.service, "\(AffirmateKeychain.appIdentifierPrefix)org.affirmate.session")
        XCTAssertEqual(AffirmateKeychain.session.accessGroup, "group.Affirmate")
        XCTAssertTrue(AffirmateKeychain.session.synchronizable)
    }
    
    func test_sessionSetAndGetString() throws {
        // Skip keychain tests in CI (no code signing = no access group support)
        if ProcessInfo.processInfo.environment["CI"] != nil || ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil {
            throw XCTSkip("Keychain tests require code signing which is not available in CI.")
        }
        let keychain = AffirmateKeychain.session
        let key = "tests.session.token"
        let value = UUID().uuidString
        try keychain.set(value, key: key)
        defer { try? keychain.remove(key) }
        XCTAssertEqual(try keychain.getString(key), value)
    }

    func test_chatSetAndGetData() throws {
        // Skip keychain tests in CI (no code signing = no access group support)
        if ProcessInfo.processInfo.environment["CI"] != nil || ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil {
            throw XCTSkip("Keychain tests require code signing which is not available in CI.")
        }
        let keychain = AffirmateKeychain.chat
        let key = "tests.chat.privateKey"
        let value = Data(UUID().uuidString.utf8)
        try keychain.set(value, key: key)
        defer { try? keychain.remove(key) }
        XCTAssertEqual(try keychain.getData(key), value)
    }
}
