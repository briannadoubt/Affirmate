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
            identityAgreementKey: identityKey.agreementKeyPair.publicKey,
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
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
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
            theirIdentityAgreementKey: aliceIdentity.agreementKeyPair.publicKey,
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
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
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
            theirIdentityAgreementKey: aliceIdentity.agreementKeyPair.publicKey,
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
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
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
        let aliceRatchet = try DoubleRatchet(
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
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
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

        let aliceRatchet = try DoubleRatchet(
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
            identityAgreementKey: Data(repeating: 0x03, count: 32),
            ephemeralKey: Data(repeating: 0x02, count: 32),
            signedPreKeyId: 1,
            oneTimePreKeyId: 42,
            message: innerMessage
        )

        let serialized = try preKeyMessage.serialize()
        let deserialized = try PreKeySignalMessage.deserialize(from: serialized)

        XCTAssertEqual(deserialized.identityKey, preKeyMessage.identityKey)
        XCTAssertEqual(deserialized.identityAgreementKey, preKeyMessage.identityAgreementKey)
        XCTAssertEqual(deserialized.ephemeralKey, preKeyMessage.ephemeralKey)
        XCTAssertEqual(deserialized.signedPreKeyId, 1)
        XCTAssertEqual(deserialized.oneTimePreKeyId, 42)
    }

    func test_preKeySignalMessage_missingIdentityAgreementKey_defaultsToIdentityKey() throws {
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
            identityAgreementKey: Data(repeating: 0x02, count: 32),
            ephemeralKey: Data(repeating: 0x03, count: 32),
            signedPreKeyId: 1,
            oneTimePreKeyId: 42,
            message: innerMessage
        )

        let serialized = try preKeyMessage.serialize()
        guard var payload = try JSONSerialization.jsonObject(with: serialized) as? [String: Any] else {
            XCTFail("Failed to serialize PreKeySignalMessage payload")
            return
        }
        payload.removeValue(forKey: "identityAgreementKey")
        let modifiedData = try JSONSerialization.data(withJSONObject: payload, options: [])

        let decoded = try PreKeySignalMessage.deserialize(from: modifiedData)

        XCTAssertEqual(decoded.identityAgreementKey, decoded.identityKey)
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
            identityAgreementKey: Data(repeating: 0x03, count: 32),
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
            XCTAssertEqual(msg.identityAgreementKey, preKeyMessage.identityAgreementKey)
        } else {
            XCTFail("Expected prekey message")
        }
    }

    // MARK: - Integration Tests

    /// Test complete end-to-end flow: Alice establishes session with Bob and they exchange messages
    func test_fullMessageFlow_aliceToBob() async throws {
        // Setup: Both parties generate their identity keys and PreKey bundles
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)
        let bobOneTimePreKey = OneTimePreKey(id: 1)

        // Bob publishes his PreKey bundle
        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
            signedPreKeyId: bobSignedPreKey.id,
            signedPreKey: bobSignedPreKey.keyPair.publicKey,
            signedPreKeySignature: bobSignedPreKey.signature,
            oneTimePreKeyId: bobOneTimePreKey.id,
            oneTimePreKey: bobOneTimePreKey.keyPair.publicKey
        )

        // Alice initiates X3DH
        let x3dh = X3DH()
        let aliceX3DHResult = try await x3dh.initiateKeyAgreement(
            identityKeyPair: aliceIdentity,
            preKeyBundle: bobBundle
        )

        // Alice initializes her ratchet
        let aliceRatchet = try DoubleRatchet(
            asInitiator: aliceX3DHResult.sharedSecret,
            theirSignedPreKey: bobBundle.signedPreKey,
            ourIdentityKey: aliceIdentity.publicKey,
            theirIdentityKey: bobIdentity.publicKey
        )

        // Alice encrypts her first message
        let aliceMessage1 = Data("Hello Bob, this is Alice!".utf8)
        let encrypted1 = try await aliceRatchet.encrypt(aliceMessage1)

        // Alice creates a PreKey message to send to Bob
        let preKeyMessage = PreKeySignalMessage(
            identityKey: aliceIdentity.publicKey,
            identityAgreementKey: aliceIdentity.agreementKeyPair.publicKey,
            ephemeralKey: aliceX3DHResult.ephemeralKeyPair.publicKey,
            signedPreKeyId: bobSignedPreKey.id,
            oneTimePreKeyId: bobOneTimePreKey.id,
            message: encrypted1
        )

        // Bob receives the PreKey message and performs X3DH
        let bobSharedSecret = try await x3dh.respondToKeyAgreement(
            identityKeyPair: bobIdentity,
            signedPreKey: bobSignedPreKey,
            oneTimePreKey: bobOneTimePreKey,
            theirIdentityAgreementKey: preKeyMessage.identityAgreementKey,
            theirEphemeralKey: preKeyMessage.ephemeralKey
        )

        // Bob initializes his ratchet
        let bobRatchet = DoubleRatchet(
            asResponder: bobSharedSecret,
            ourSignedPreKey: bobSignedPreKey,
            ourIdentityKey: bobIdentity.publicKey,
            theirIdentityKey: aliceIdentity.publicKey
        )

        // Bob decrypts Alice's first message
        let decrypted1 = try await bobRatchet.decrypt(preKeyMessage.message)
        XCTAssertEqual(decrypted1, aliceMessage1)
        XCTAssertEqual(String(data: decrypted1, encoding: .utf8), "Hello Bob, this is Alice!")

        // Bob replies
        let bobMessage1 = Data("Hi Alice, nice to hear from you!".utf8)
        let bobEncrypted1 = try await bobRatchet.encrypt(bobMessage1)
        let aliceDecrypted1 = try await aliceRatchet.decrypt(bobEncrypted1)
        XCTAssertEqual(aliceDecrypted1, bobMessage1)

        // Alice sends another message
        let aliceMessage2 = Data("How's the encryption working?".utf8)
        let encrypted2 = try await aliceRatchet.encrypt(aliceMessage2)
        let decrypted2 = try await bobRatchet.decrypt(encrypted2)
        XCTAssertEqual(decrypted2, aliceMessage2)

        // Bob sends final message
        let bobMessage2 = Data("Perfect! Forward secrecy is amazing.".utf8)
        let bobEncrypted2 = try await bobRatchet.encrypt(bobMessage2)
        let aliceDecrypted2 = try await aliceRatchet.decrypt(bobEncrypted2)
        XCTAssertEqual(aliceDecrypted2, bobMessage2)
    }

    /// Test out-of-order message delivery
    func test_outOfOrderMessages() async throws {
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)

        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
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

        let aliceRatchet = try DoubleRatchet(
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

        // Alice sends 3 messages
        let message1 = Data("Message 1".utf8)
        let message2 = Data("Message 2".utf8)
        let message3 = Data("Message 3".utf8)

        let encrypted1 = try await aliceRatchet.encrypt(message1)
        let encrypted2 = try await aliceRatchet.encrypt(message2)
        let encrypted3 = try await aliceRatchet.encrypt(message3)

        // Bob receives them out of order: 3, 1, 2
        let decrypted3 = try await bobRatchet.decrypt(encrypted3)
        XCTAssertEqual(decrypted3, message3)

        let decrypted1 = try await bobRatchet.decrypt(encrypted1)
        XCTAssertEqual(decrypted1, message1)

        let decrypted2 = try await bobRatchet.decrypt(encrypted2)
        XCTAssertEqual(decrypted2, message2)
    }

    /// Test message tampering detection
    func test_tamperedMessageRejection() async throws {
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)

        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
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

        let aliceRatchet = try DoubleRatchet(
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
        let message = Data("Secret message".utf8)
        var encrypted = try await aliceRatchet.encrypt(message)

        // Tamper with the ciphertext
        encrypted = SignalMessage(
            header: encrypted.header,
            ciphertext: Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]),
            mac: encrypted.mac
        )

        // Bob should reject the tampered message
        do {
            _ = try await bobRatchet.decrypt(encrypted)
            XCTFail("Should have thrown decryption error for tampered message")
        } catch SignalProtocolError.decryptionFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Test concurrent session establishment (race condition)
    func test_concurrentSessionEstablishment() async throws {
        // Both Alice and Bob try to initiate a session simultaneously
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let aliceSignedPreKey = try SignedPreKey(id: 1, identityKey: aliceIdentity)
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)

        let aliceBundle = PreKeyBundle(
            identityKey: aliceIdentity.publicKey,
            identityAgreementKey: aliceIdentity.agreementKeyPair.publicKey,
            signedPreKeyId: aliceSignedPreKey.id,
            signedPreKey: aliceSignedPreKey.keyPair.publicKey,
            signedPreKeySignature: aliceSignedPreKey.signature,
            oneTimePreKeyId: nil,
            oneTimePreKey: nil
        )

        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
            signedPreKeyId: bobSignedPreKey.id,
            signedPreKey: bobSignedPreKey.keyPair.publicKey,
            signedPreKeySignature: bobSignedPreKey.signature,
            oneTimePreKeyId: nil,
            oneTimePreKey: nil
        )

        let x3dh = X3DH()

        // Both parties establish sessions concurrently
        async let aliceSession = x3dh.initiateKeyAgreement(
            identityKeyPair: aliceIdentity,
            preKeyBundle: bobBundle
        )
        async let bobSession = x3dh.initiateKeyAgreement(
            identityKeyPair: bobIdentity,
            preKeyBundle: aliceBundle
        )

        let (aliceResult, bobResult) = try await (aliceSession, bobSession)

        // Both should succeed
        XCTAssertEqual(aliceResult.sharedSecret.count, 32)
        XCTAssertEqual(bobResult.sharedSecret.count, 32)
        // Note: The shared secrets will be different since they're initiating to each other
    }

    // MARK: - Session Persistence Tests

    /// Test that ratchet state can be persisted and restored
    func test_ratchetStatePersistence() async throws {
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)

        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
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

        // Create Alice's ratchet and send a message
        let aliceRatchet = try DoubleRatchet(
            asInitiator: aliceResult.sharedSecret,
            theirSignedPreKey: bobSignedPreKey.keyPair.publicKey,
            ourIdentityKey: aliceIdentity.publicKey,
            theirIdentityKey: bobIdentity.publicKey
        )

        let message1 = Data("First message".utf8)
        let encrypted1 = try await aliceRatchet.encrypt(message1)

        // Get the state for persistence
        let persistedState = await aliceRatchet.getState()

        // Simulate app restart - create new ratchet from persisted state
        let restoredRatchet = DoubleRatchet(
            state: persistedState,
            ourIdentityKey: aliceIdentity.publicKey,
            theirIdentityKey: bobIdentity.publicKey
        )

        // Send another message with the restored ratchet
        let message2 = Data("Second message after restoration".utf8)
        let encrypted2 = try await restoredRatchet.encrypt(message2)

        // Bob should be able to decrypt both messages
        let bobRatchet = DoubleRatchet(
            asResponder: aliceResult.sharedSecret,
            ourSignedPreKey: bobSignedPreKey,
            ourIdentityKey: bobIdentity.publicKey,
            theirIdentityKey: aliceIdentity.publicKey
        )

        let decrypted1 = try await bobRatchet.decrypt(encrypted1)
        XCTAssertEqual(decrypted1, message1)

        let decrypted2 = try await bobRatchet.decrypt(encrypted2)
        XCTAssertEqual(decrypted2, message2)
    }

    /// Test that state codable round-trip preserves all data
    func test_ratchetStateCodable() async throws {
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)

        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
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

        let aliceRatchet = try DoubleRatchet(
            asInitiator: aliceResult.sharedSecret,
            theirSignedPreKey: bobSignedPreKey.keyPair.publicKey,
            ourIdentityKey: aliceIdentity.publicKey,
            theirIdentityKey: bobIdentity.publicKey
        )

        // Send some messages to advance the ratchet state
        _ = try await aliceRatchet.encrypt(Data("Message 1".utf8))
        _ = try await aliceRatchet.encrypt(Data("Message 2".utf8))

        // Get state and encode it
        let originalState = await aliceRatchet.getState()
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalState)

        // Decode it back
        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(RatchetState.self, from: encodedData)

        // Verify critical fields are preserved
        XCTAssertEqual(decodedState.rootKey, originalState.rootKey)
        XCTAssertEqual(decodedState.sendingChainKey, originalState.sendingChainKey)
        XCTAssertEqual(decodedState.receivingChainKey, originalState.receivingChainKey)
        XCTAssertEqual(decodedState.sendingMessageNumber, originalState.sendingMessageNumber)
        XCTAssertEqual(decodedState.receivingMessageNumber, originalState.receivingMessageNumber)
        XCTAssertEqual(decodedState.dhKeyPair.publicKey, originalState.dhKeyPair.publicKey)
        XCTAssertEqual(decodedState.theirDHPublicKey, originalState.theirDHPublicKey)
    }

    /// Test session persistence with skipped messages
    func test_sessionPersistenceWithSkippedMessages() async throws {
        let aliceIdentity = IdentityKeyPair()
        let bobIdentity = IdentityKeyPair()
        let bobSignedPreKey = try SignedPreKey(id: 1, identityKey: bobIdentity)

        let bobBundle = PreKeyBundle(
            identityKey: bobIdentity.publicKey,
            identityAgreementKey: bobIdentity.agreementKeyPair.publicKey,
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

        let aliceRatchet = try DoubleRatchet(
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

        // Alice sends 3 messages
        let message1 = Data("Message 1".utf8)
        let message2 = Data("Message 2".utf8)
        let message3 = Data("Message 3".utf8)

        let encrypted1 = try await aliceRatchet.encrypt(message1)
        let encrypted2 = try await aliceRatchet.encrypt(message2)
        let encrypted3 = try await aliceRatchet.encrypt(message3)

        // Bob receives message 3 first (skipping 1 and 2)
        let decrypted3 = try await bobRatchet.decrypt(encrypted3)
        XCTAssertEqual(decrypted3, message3)

        // Bob's app "crashes" - persist and restore state
        let bobState = await bobRatchet.getState()
        let restoredBobRatchet = DoubleRatchet(
            state: bobState,
            ourIdentityKey: bobIdentity.publicKey,
            theirIdentityKey: aliceIdentity.publicKey
        )

        // Bob receives the skipped messages after restoration
        let decrypted1 = try await restoredBobRatchet.decrypt(encrypted1)
        XCTAssertEqual(decrypted1, message1)

        let decrypted2 = try await restoredBobRatchet.decrypt(encrypted2)
        XCTAssertEqual(decrypted2, message2)
    }
}
