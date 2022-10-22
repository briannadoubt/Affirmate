//
//  AffirmateKeychainTests.swift
//  AffirmateTests
//
//  Created by Bri on 10/21/22.
//

@testable import Affirmate
import XCTest

final class AffirmateKeychainTests: XCTestCase {
    
    var keychain: AffirmateKeychain!

    override func setUpWithError() throws {
        try super.setUpWithError()
        keychain = AffirmateKeychain()
    }

    override func tearDownWithError() throws {
        keychain = nil
        try super.tearDownWithError()
    }
    
    func test_appIdentifierPrefix() {
        XCTAssertEqual(AffirmateKeychain.appIdentifierPrefix, Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String)
    }
    
    func test_chatService() {
        XCTAssertEqual(AffirmateKeychain.chatService, "\(AffirmateKeychain.appIdentifierPrefix)org.affirmate.chat")
    }
    
    func test_sessionService() {
        XCTAssertEqual(AffirmateKeychain.sessionService, "\(AffirmateKeychain.appIdentifierPrefix)org.affirmate.session")
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
    
    func test_password() throws {
        XCTAssertEqual(AffirmateKeychain.password.server, URL(string: "https://affirmate.org/")!)
        XCTAssertEqual(AffirmateKeychain.password.protocolType, .https)
        XCTAssertEqual(AffirmateKeychain.password.accessGroup, "group.Affirmate")
        XCTAssertEqual(AffirmateKeychain.password.authenticationType, .httpBasic)
        XCTAssertTrue(AffirmateKeychain.password.synchronizable)
    }
}
