//
//  AffirmateCryptoTests.swift
//  AffirmateTests
//
//  Created by Bri on 10/22/22.
//

@testable import Affirmate
import CryptoKit
import KeychainAccess
import XCTest

final class AffirmateCryptoTests: XCTestCase {
    
    var crypto: AffirmateCrypto!
    let chatId = UUID()
    let messageText = "Test message"
    var keychain: Keychain!

    override func setUpWithError() throws {
        self.keychain = Keychain()
        do { try keychain.removeAll() } catch { }
        self.crypto = AffirmateCrypto(keychain: keychain)
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        do { try keychain.removeAll() } catch { }
        self.crypto = nil
        self.keychain = nil
        try super.tearDownWithError()
    }

    func test_generateSalt() async throws {
        let salt = try await crypto.generateSalt()
        XCTAssertEqual(salt.count, 32)
    }
    
    func test_generateSigningKeyPair() async throws {
        let (signingPublicKey, signingPrivateKey) = try await crypto.generateSigningKeyPair(for: chatId)
        XCTAssertEqual(signingPublicKey.count, 32)
        XCTAssertEqual(signingPrivateKey.count, 32)
        XCTAssertNoThrow(try Curve25519.Signing.PublicKey(rawRepresentation: signingPublicKey))
        XCTAssertNoThrow(try Curve25519.Signing.PrivateKey(rawRepresentation: signingPrivateKey))
    }
    
    func test_generateEncryptionKeyPair() async throws {
        let (encryptionPublicKey, encryptionPrivateKey) = try await crypto.generateEncryptionKeyPair(for: chatId)
        XCTAssertEqual(encryptionPublicKey.count, 32)
        XCTAssertEqual(encryptionPrivateKey.count, 32)
        XCTAssertNoThrow(try Curve25519.KeyAgreement.PublicKey(rawRepresentation: encryptionPublicKey))
        XCTAssertNoThrow(try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: encryptionPrivateKey))
    }
    
    func test_signingKey_for_chatId() async throws {
        let signingKey = await crypto.signingKey(for: chatId)
        XCTAssertEqual(signingKey, "keys.signing." + chatId.uuidString)
    }
    
    func test_encryptionKey_for_chatId() async throws {
        let privateEncryptionKey = await crypto.encryptionKey(for: chatId)
        XCTAssertEqual(privateEncryptionKey, "keys.encryption." + chatId.uuidString)
    }
    
    func test_store_signingKey() async throws {
        let (_, privateKey) = try await crypto.generateSigningKeyPair(for: chatId)
        XCTAssertNoThrow(try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey))
    }
    
    func test_store_encryptionKey() async throws {
        let (_, privateEncryptionKey) = try await crypto.generateEncryptionKeyPair(for: chatId)
        XCTAssertNoThrow(try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateEncryptionKey))
    }
    
    func test_getPrivateEncryptionKey() async throws {
        let (_, privateEncryptionKeyData) = try await crypto.generateEncryptionKeyPair(for: chatId)
        let wrappedPrivateEncryptionKey = try await crypto.getPrivateEncryptionKey(for: chatId)
        let privateEncryptionKey = try XCTUnwrap(wrappedPrivateEncryptionKey)
        let expectedOutput = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateEncryptionKeyData)
        XCTAssertEqual(privateEncryptionKey.rawRepresentation.base64EncodedString(), expectedOutput.rawRepresentation.base64EncodedString())
    }
    
    func test_getPrivateSigningKey() async throws {
        let (_, privateSigningKeyData) = try await crypto.generateSigningKeyPair(for: chatId)
        let wrappedPrivateSigningKey = try await crypto.getPrivateSigningKey(for: chatId)
        let privateEncryptionKey = try XCTUnwrap(wrappedPrivateSigningKey)
        let expectedOutput = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateSigningKeyData)
        XCTAssertEqual(privateEncryptionKey.rawRepresentation.base64EncodedString(), expectedOutput.rawRepresentation.base64EncodedString())
    }
    
    func test_encrypt() async throws {
        let messageTextData = try XCTUnwrap(messageText.data(using: .utf8))
        let salt = try await crypto.generateSalt()
        let (_, privateSigningKeyData) = try await crypto.generateSigningKeyPair(for: chatId)
        let (publicEncryptionKeyData, _) = try await crypto.generateEncryptionKeyPair(for: chatId)
        let privateSigningKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateSigningKeyData)
        let publicEncryptionKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicEncryptionKeyData)
        let _ = try await crypto.encrypt(messageTextData, salt: salt, to: publicEncryptionKey, signedBy: privateSigningKey)
    }
    
    func test_decrypt() async throws {
        let messageTextData = try XCTUnwrap(messageText.data(using: .utf8))
        let salt = try await crypto.generateSalt()
        let (publicSigningKeyData, privateSigningKeyData) = try await crypto.generateSigningKeyPair(for: chatId)
        let (publicEncryptionKeyData, privateEncryptionKeyData) = try await crypto.generateEncryptionKeyPair(for: chatId)
        let privateSigningKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateSigningKeyData)
        let publicEncryptionKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicEncryptionKeyData)
        let sealedMessage = try await crypto.encrypt(messageTextData, salt: salt, to: publicEncryptionKey, signedBy: privateSigningKey)
        
        let privateEncryptionKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateEncryptionKeyData)
        let publicSigningKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicSigningKeyData)
        let decryptedData = try await crypto.decrypt(sealedMessage, salt: salt, using: privateEncryptionKey, from: publicSigningKey)
        
        let decryptedText = try XCTUnwrap(String(data: decryptedData, encoding: .utf8))
        
        XCTAssertEqual(decryptedText, messageText)
    }
}
