//
//  SignalProtocolTests.swift
//  AffirmateTests
//
//  Tests for Signal Protocol implementation.
//

#if os(watchOS)
@testable import AffirmateWatch
#else
@testable import Affirmate
#endif
import AffirmateShared
import CryptoKit
import KeychainAccess
import XCTest

final class SignalProtocolTests: XCTestCase {

    var keychain: Keychain!

    override func setUpWithError() throws {
        self.keychain = Keychain(service: "org.affirmate.test.signal")
        try? keychain.removeAll()
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        try? keychain.removeAll()
        self.keychain = nil
        try super.tearDownWithError()
    }

    // MARK: - Identity Key Tests

    func test_identityKeyPair_generation() throws {
        let keyPair = IdentityKeyPair()
        XCTAssertEqual(keyPair.privateKey.count, 32)
        XCTAssertEqual(keyPair.publicKey.count, 32)
    }

    func test_identityKeyPair_signing() throws {
        let keyPair = IdentityKeyPair()
        let data = Data("Test message".utf8)
        let signature = try keyPair.sign(data)
        XCTAssertEqual(signature.count, 64)

        // Verify signature
        let isValid = try IdentityKeyPair.verify(signature: signature, for: data, from: keyPair.publicKey)
        XCTAssertTrue(isValid)
    }

    func test_identityKeyPair_invalidSignature() throws {
        let keyPair = IdentityKeyPair()
        let data = Data("Test message".utf8)
        let signature = try keyPair.sign(data)

        // Tamper with data
        let tamperedData = Data("Tampered message".utf8)
        let isValid = try IdentityKeyPair.verify(signature: signature, for: tamperedData, from: keyPair.publicKey)
        XCTAssertFalse(isValid)
    }

    // MARK: - Key Agreement Tests

    func test_keyAgreementKeyPair_generation() throws {
        let keyPair = KeyAgreementKeyPair()
        XCTAssertEqual(keyPair.privateKey.count, 32)
        XCTAssertEqual(keyPair.publicKey.count, 32)
    }

    func test_keyAgreementKeyPair_sharedSecret() throws {
        let aliceKeyPair = KeyAgreementKeyPair()
        let bobKeyPair = KeyAgreementKeyPair()

        // Both parties should derive the same shared secret
        let aliceSharedSecret = try aliceKeyPair.sharedSecret(with: bobKeyPair.publicKey)
        let bobSharedSecret = try bobKeyPair.sharedSecret(with: aliceKeyPair.publicKey)

        var aliceSecretData = Data()
        var bobSecretData = Data()
        aliceSharedSecret.withUnsafeBytes { aliceSecretData.append(contentsOf: $0) }
        bobSharedSecret.withUnsafeBytes { bobSecretData.append(contentsOf: $0) }

        XCTAssertEqual(aliceSecretData, bobSecretData)
    }

    // MARK: - Signed PreKey Tests

    func test_signedPreKey_creation() throws {
        let identityKey = IdentityKeyPair()
        let signedPreKey = try SignedPreKey(id: 1, identityKey: identityKey)

        XCTAssertEqual(signedPreKey.id, 1)
        XCTAssertEqual(signedPreKey.keyPair.publicKey.count, 32)
        XCTAssertEqual(signedPreKey.signature.count, 64)
    }

    func test_signedPreKey_verification() throws {
        let identityKey = IdentityKeyPair()
        let signedPreKey = try SignedPreKey(id: 1, identityKey: identityKey)

        let isValid = try signedPreKey.verify(with: identityKey.publicKey)
        XCTAssertTrue(isValid)
    }

    func test_signedPreKey_invalidVerification() throws {
        let identityKey = IdentityKeyPair()
        let otherIdentityKey = IdentityKeyPair()
        let signedPreKey = try SignedPreKey(id: 1, identityKey: identityKey)

        // Verify with wrong identity key should fail
        let isValid = try signedPreKey.verify(with: otherIdentityKey.publicKey)
        XCTAssertFalse(isValid)
    }

    // MARK: - One-Time PreKey Tests

    func test_oneTimePreKey_creation() {
        let preKey = OneTimePreKey(id: 42)
        XCTAssertEqual(preKey.id, 42)
        XCTAssertEqual(preKey.keyPair.publicKey.count, 32)
    }

    // MARK: - PreKey Bundle Tests

    func test_preKeyBundle_signatureVerification() throws {
        let identityKey = IdentityKeyPair()
        let signedPreKey = try SignedPreKey(id: 1, identityKey: identityKey)
        let oneTimePreKey = OneTimePreKey(id: 1)

        let bundle = PreKeyBundle(
            identityKey: identityKey.publicKey,
            signedPreKeyId: signedPreKey.id,
            signedPreKey: signedPreKey.keyPair.publicKey,
            signedPreKeySignature: signedPreKey.signature,
            oneTimePreKeyId: oneTimePreKey.id,
            oneTimePreKey: oneTimePreKey.keyPair.publicKey
        )

        let isValid = try bundle.verifySignature()
        XCTAssertTrue(isValid)
    }

    // MARK: - X3DH Tests

    func test_x3dh_keyAgreement() async throws {
        // Alice (initiator) and Bob (responder) setup
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)
        let bobOneTimePreKey = OneTimePreKey(id: 1)

        // Bob's PreKey bundle
        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            signedPreKeyId: bobSignedPreKey.id,
            signedPreKey: bobSignedPreKey.keyPair.publicKey,
            signedPreKeySignature: bobSignedPreKey.signature,
            oneTimePreKeyId: bobOneTimePreKey.id,
            oneTimePreKey: bobOneTimePreKey.keyPair.publicKey
        )

        // Alice initiates key agreement
        let x3dh = X3DH()
        let aliceResult = try await x3dh.initiateKeyAgreement(
            identityKeyPair: aliceIdentity,
            preKeyBundle: bobBundle
        )

        XCTAssertEqual(aliceResult.sharedSecret.count, 32)
        XCTAssertEqual(aliceResult.usedSignedPreKeyId, 1)
        XCTAssertEqual(aliceResult.usedOneTimePreKeyId, 1)

        // Bob responds
        let bobSecret = try await x3dh.respondToKeyAgreement(
            identityKeyPair: bobIdentity,
            signedPreKey: bobSignedPreKey,
            oneTimePreKey: bobOneTimePreKey,
            theirIdentityKey: aliceIdentity.publicKey,
            theirEphemeralKey: aliceResult.ephemeralKeyPair.publicKey
        )

        // Both should derive the same shared secret
        XCTAssertEqual(aliceResult.sharedSecret, bobSecret)
    }

    func test_x3dh_withoutOneTimePreKey() async throws {
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)

        // Bundle without one-time PreKey
        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            signedPreKeyId: bobSignedPreKey.id,
            signedPreKey: bobSignedPreKey.keyPair.publicKey,
            signedPreKeySignature: bobSignedPreKey.signature,
            oneTimePreKeyId: nil,
            oneTimePreKey: nil
        )

        let x3dh = X3DH()
        let aliceResult = try await x3dh.initiateKeyAgreement(
            identityKeyPair: aliceIdentity,
            preKeyBundle: bobBundle
        )

        XCTAssertNil(aliceResult.usedOneTimePreKeyId)

        let bobSecret = try await x3dh.respondToKeyAgreement(
            identityKeyPair: bobIdentity,
            signedPreKey: bobSignedPreKey,
            oneTimePreKey: nil,
            theirIdentityKey: aliceIdentity.publicKey,
            theirEphemeralKey: aliceResult.ephemeralKeyPair.publicKey
        )

        XCTAssertEqual(aliceResult.sharedSecret, bobSecret)
    }

    // MARK: - Double Ratchet Tests

    func test_doubleRatchet_encryptDecrypt() async throws {
        // Setup session keys
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)

        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            signedPreKeyId: bobSignedPreKey.id,
            signedPreKey: bobSignedPreKey.keyPair.publicKey,
            signedPreKeySignature: bobSignedPreKey.signature,
            oneTimePreKeyId: nil,
            oneTimePreKey: nil
        )

        // X3DH key agreement
        let x3dh = X3DH()
        let aliceResult = try await x3dh.initiateKeyAgreement(
            identityKeyPair: aliceIdentity,
            preKeyBundle: bobBundle
        )

        // Initialize ratchets
        let aliceRatchet = DoubleRatchet(
            asInitiator: aliceResult.sharedSecret,
            theirSignedPreKey: bobSignedPreKey.keyPair.publicKey,
            ourIdentityKey: aliceIdentity.publicKey,
            theirIdentityKey: bobIdentity.publicKey
        )

        let bobRatchet = DoubleRatchet(
            asResponder: aliceResult.sharedSecret,
            ourSignedPreKey: bobSignedPreKey,
            ourIdentityKey: bobIdentity.publicKey,
            theirIdentityKey: aliceIdentity.publicKey
        )

        // Alice sends a message
        let plaintext = Data("Hello, Bob!".utf8)
        let encryptedMessage = try await aliceRatchet.encrypt(plaintext)

        // Bob decrypts
        let decryptedData = try await bobRatchet.decrypt(encryptedMessage)
        XCTAssertEqual(decryptedData, plaintext)
    }

    func test_doubleRatchet_multipleMessages() async throws {
        // Setup
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)

        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            signedPreKeyId: bobSignedPreKey.id,
            signedPreKey: bobSignedPreKey.keyPair.publicKey,
            signedPreKeySignature: bobSignedPreKey.signature,
            oneTimePreKeyId: nil,
            oneTimePreKey: nil
        )

        let x3dh = X3DH()
        let aliceResult = try await x3dh.initiateKeyAgreement(
            identityKeyPair: aliceIdentity,
            preKeyBundle: bobBundle
        )

        let aliceRatchet = DoubleRatchet(
            asInitiator: aliceResult.sharedSecret,
            theirSignedPreKey: bobSignedPreKey.keyPair.publicKey,
            ourIdentityKey: aliceIdentity.publicKey,
            theirIdentityKey: bobIdentity.publicKey
        )

        let bobRatchet = DoubleRatchet(
            asResponder: aliceResult.sharedSecret,
            ourSignedPreKey: bobSignedPreKey,
            ourIdentityKey: bobIdentity.publicKey,
            theirIdentityKey: aliceIdentity.publicKey
        )

        // Send multiple messages
        let messages = ["Hello!", "How are you?", "I'm using Signal Protocol!"]

        for message in messages {
            let plaintext = Data(message.utf8)
            let encrypted = try await aliceRatchet.encrypt(plaintext)
            let decrypted = try await bobRatchet.decrypt(encrypted)
            XCTAssertEqual(String(data: decrypted, encoding: .utf8), message)
        }

        // Bob replies
        let bobReply = Data("Great to hear!".utf8)
        let bobEncrypted = try await bobRatchet.encrypt(bobReply)
        let aliceDecrypted = try await aliceRatchet.decrypt(bobEncrypted)
        XCTAssertEqual(aliceDecrypted, bobReply)
    }

    // MARK: - PreKey Manager Tests

    func test_preKeyManager_generateSignedPreKey() async throws {
        let manager = PreKeyManager()
        let identityKey = IdentityKeyPair()

        let signedPreKey = try await manager.generateSignedPreKey(identityKey: identityKey)
        XCTAssertEqual(signedPreKey.id, 1)

        let storedKey = await manager.getSignedPreKey()
        XCTAssertEqual(storedKey?.id, signedPreKey.id)
    }

    func test_preKeyManager_generateOneTimePreKeys() async {
        let manager = PreKeyManager()

        let preKeys = await manager.generateOneTimePreKeys(count: 10)
        XCTAssertEqual(preKeys.count, 10)

        let count = await manager.getOneTimePreKeyCount()
        XCTAssertEqual(count, 10)
    }

    func test_preKeyManager_consumeOneTimePreKey() async {
        let manager = PreKeyManager()
        let preKeys = await manager.generateOneTimePreKeys(count: 5)

        let consumed = await manager.consumeOneTimePreKey(id: preKeys[0].id)
        XCTAssertNotNil(consumed)
        XCTAssertEqual(consumed?.id, preKeys[0].id)

        // Consuming again should return nil
        let consumedAgain = await manager.consumeOneTimePreKey(id: preKeys[0].id)
        XCTAssertNil(consumedAgain)

        let count = await manager.getOneTimePreKeyCount()
        XCTAssertEqual(count, 4)
    }

    // MARK: - Message Serialization Tests

    func test_signalMessage_serialization() throws {
        let header = MessageHeader(
            dhPublicKey: Data(repeating: 0x42, count: 32),
            previousChainCount: 5,
            messageNumber: 10
        )

        let message = SignalMessage(
            header: header,
            ciphertext: Data("encrypted".utf8),
            mac: Data(repeating: 0x00, count: 12)
        )

        let serialized = try message.serialize()
        let deserialized = try SignalMessage.deserialize(from: serialized)

        XCTAssertEqual(deserialized.header.dhPublicKey, header.dhPublicKey)
        XCTAssertEqual(deserialized.header.previousChainCount, 5)
        XCTAssertEqual(deserialized.header.messageNumber, 10)
        XCTAssertEqual(deserialized.ciphertext, message.ciphertext)
    }

    func test_preKeySignalMessage_serialization() throws {
        let header = MessageHeader(
            dhPublicKey: Data(repeating: 0x42, count: 32),
            previousChainCount: 0,
            messageNumber: 0
        )

        let innerMessage = SignalMessage(
            header: header,
            ciphertext: Data("encrypted".utf8),
            mac: Data(repeating: 0x00, count: 12)
        )

        let preKeyMessage = PreKeySignalMessage(
            identityKey: Data(repeating: 0x01, count: 32),
            ephemeralKey: Data(repeating: 0x02, count: 32),
            signedPreKeyId: 1,
            oneTimePreKeyId: 42,
            message: innerMessage
        )

        let serialized = try preKeyMessage.serialize()
        let deserialized = try PreKeySignalMessage.deserialize(from: serialized)

        XCTAssertEqual(deserialized.identityKey, preKeyMessage.identityKey)
        XCTAssertEqual(deserialized.ephemeralKey, preKeyMessage.ephemeralKey)
        XCTAssertEqual(deserialized.signedPreKeyId, 1)
        XCTAssertEqual(deserialized.oneTimePreKeyId, 42)
    }

    // MARK: - Encrypted Message Container Tests

    func test_encryptedMessageContainer_signalMessage() throws {
        let header = MessageHeader(
            dhPublicKey: Data(repeating: 0x42, count: 32),
            previousChainCount: 0,
            messageNumber: 0
        )

        let message = SignalMessage(
            header: header,
            ciphertext: Data("test".utf8),
            mac: Data(repeating: 0x00, count: 12)
        )

        let container = EncryptedMessageContainer.signalMessage(message)
        let serialized = try container.serialize()
        let deserialized = try EncryptedMessageContainer.deserialize(from: serialized)

        if case .signalMessage(let msg) = deserialized {
            XCTAssertEqual(msg.header.dhPublicKey, header.dhPublicKey)
        } else {
            XCTFail("Expected signal message")
        }
    }

    func test_encryptedMessageContainer_preKeyMessage() throws {
        let header = MessageHeader(
            dhPublicKey: Data(repeating: 0x42, count: 32),
            previousChainCount: 0,
            messageNumber: 0
        )

        let innerMessage = SignalMessage(
            header: header,
            ciphertext: Data("test".utf8),
            mac: Data(repeating: 0x00, count: 12)
        )

        let preKeyMessage = PreKeySignalMessage(
            identityKey: Data(repeating: 0x01, count: 32),
            ephemeralKey: Data(repeating: 0x02, count: 32),
            signedPreKeyId: 1,
            oneTimePreKeyId: nil,
            message: innerMessage
        )

        let container = EncryptedMessageContainer.preKeyMessage(preKeyMessage)
        let serialized = try container.serialize()
        let deserialized = try EncryptedMessageContainer.deserialize(from: serialized)

        if case .preKeyMessage(let msg) = deserialized {
            XCTAssertEqual(msg.signedPreKeyId, 1)
            XCTAssertNil(msg.oneTimePreKeyId)
        } else {
            XCTFail("Expected prekey message")
        }
    }
}
