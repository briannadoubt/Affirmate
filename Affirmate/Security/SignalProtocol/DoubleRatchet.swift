//
//  DoubleRatchet.swift
//  Affirmate
//
//  Double Ratchet algorithm implementation.
//  Reference: https://signal.org/docs/specifications/doubleratchet/
//

import CryptoKit
import Foundation

// MARK: - Double Ratchet Constants

private enum DoubleRatchetConstants {
    /// Maximum number of skipped message keys to store
    static let maxSkippedMessages = 1000
    /// KDF info for root key derivation
    static let rootKeyInfo = Data("DoubleRatchet_RootKey".utf8)
    /// KDF info for chain key derivation
    static let chainKeyInfo = Data("DoubleRatchet_ChainKey".utf8)
    /// KDF info for message key derivation
    static let messageKeyConstant: UInt8 = 0x01
    /// KDF info for next chain key derivation
    static let chainKeyConstant: UInt8 = 0x02
}

// MARK: - Ratchet State

/// The state maintained by each party in the Double Ratchet protocol
struct RatchetState: Codable {
    /// Our DH key pair for the ratchet
    var dhKeyPair: KeyAgreementKeyPair
    /// Their DH public key
    var theirDHPublicKey: Data?
    /// Root key (32 bytes)
    var rootKey: Data
    /// Sending chain key
    var sendingChainKey: Data?
    /// Receiving chain key
    var receivingChainKey: Data?
    /// Number of messages sent in current sending chain
    var sendingMessageNumber: UInt32 = 0
    /// Number of messages received in current receiving chain
    var receivingMessageNumber: UInt32 = 0
    /// Previous sending chain length (for header)
    var previousSendingChainLength: UInt32 = 0
    /// Skipped message keys: [DHPublicKey: [MessageNumber: MessageKey]]
    var skippedMessageKeys: [Data: [UInt32: Data]] = [:]
}

// MARK: - Double Ratchet

/// Double Ratchet algorithm for forward-secure end-to-end encryption.
/// Provides both forward secrecy and post-compromise security.
actor DoubleRatchet {

    private var state: RatchetState

    /// Our identity key for associated data
    private let ourIdentityKey: Data
    /// Their identity key for associated data
    private let theirIdentityKey: Data

    // MARK: - Initialization

    /// Initialize as the session initiator (Alice).
    /// Called after X3DH completes.
    ///
    /// - Parameters:
    ///   - sharedSecret: The shared secret from X3DH
    ///   - theirSignedPreKey: Bob's signed PreKey public key (becomes their initial DH key)
    ///   - ourIdentityKey: Our public identity key
    ///   - theirIdentityKey: Their public identity key
    init(
        asInitiator sharedSecret: Data,
        theirSignedPreKey: Data,
        ourIdentityKey: Data,
        theirIdentityKey: Data
    ) {
        // Generate our first DH key pair
        let dhKeyPair = KeyAgreementKeyPair()

        // Perform initial DH to get first sending chain
        let dhOutput = try? dhKeyPair.sharedSecret(with: theirSignedPreKey)
        let dhData = dhOutput?.withUnsafeBytes { Data($0) } ?? Data()

        // Derive root key and sending chain key
        let (rootKey, chainKey) = Self.kdfRootKey(
            rootKey: sharedSecret,
            dhOutput: dhData
        )

        self.state = RatchetState(
            dhKeyPair: dhKeyPair,
            theirDHPublicKey: theirSignedPreKey,
            rootKey: rootKey,
            sendingChainKey: chainKey,
            receivingChainKey: nil
        )
        self.ourIdentityKey = ourIdentityKey
        self.theirIdentityKey = theirIdentityKey
    }

    /// Initialize as the session responder (Bob).
    /// Called after receiving Alice's first message.
    ///
    /// - Parameters:
    ///   - sharedSecret: The shared secret from X3DH
    ///   - ourSignedPreKey: Our signed PreKey key pair
    ///   - ourIdentityKey: Our public identity key
    ///   - theirIdentityKey: Their public identity key
    init(
        asResponder sharedSecret: Data,
        ourSignedPreKey: SignedPreKey,
        ourIdentityKey: Data,
        theirIdentityKey: Data
    ) {
        self.state = RatchetState(
            dhKeyPair: ourSignedPreKey.keyPair,
            theirDHPublicKey: nil,
            rootKey: sharedSecret,
            sendingChainKey: nil,
            receivingChainKey: nil
        )
        self.ourIdentityKey = ourIdentityKey
        self.theirIdentityKey = theirIdentityKey
    }

    /// Initialize from existing state (for session restoration)
    init(
        state: RatchetState,
        ourIdentityKey: Data,
        theirIdentityKey: Data
    ) {
        self.state = state
        self.ourIdentityKey = ourIdentityKey
        self.theirIdentityKey = theirIdentityKey
    }

    // MARK: - Encryption

    /// Encrypt a message using the Double Ratchet.
    ///
    /// - Parameter plaintext: The message to encrypt
    /// - Returns: The encrypted Signal message
    func encrypt(_ plaintext: Data) throws -> SignalMessage {
        // Derive message key from sending chain
        guard var chainKey = state.sendingChainKey else {
            throw SignalProtocolError.chainKeyExhausted
        }

        let (messageKey, nextChainKey) = Self.kdfChainKey(chainKey: chainKey)
        state.sendingChainKey = nextChainKey

        // Create header
        let header = MessageHeader(
            dhPublicKey: state.dhKeyPair.publicKey,
            previousChainCount: state.previousSendingChainLength,
            messageNumber: state.sendingMessageNumber
        )
        state.sendingMessageNumber += 1

        // Serialize header for AAD
        let headerData = try JSONEncoder().encode(header)

        // Generate associated data
        let associatedData = generateAssociatedData(
            senderIdentityKey: ourIdentityKey,
            recipientIdentityKey: theirIdentityKey
        ) + headerData

        // Encrypt with ChaChaPoly
        let symmetricKey = SymmetricKey(data: messageKey)
        let sealedBox = try ChaChaPoly.seal(plaintext, using: symmetricKey, authenticating: associatedData)

        return SignalMessage(
            header: header,
            ciphertext: sealedBox.ciphertext + sealedBox.tag,
            mac: sealedBox.nonce.withUnsafeBytes { Data($0) }
        )
    }

    // MARK: - Decryption

    /// Decrypt a message using the Double Ratchet.
    ///
    /// - Parameter message: The encrypted Signal message
    /// - Returns: The decrypted plaintext
    func decrypt(_ message: SignalMessage) throws -> Data {
        // Check if this is from a skipped message
        if let plaintext = try trySkippedMessageKeys(message: message) {
            return plaintext
        }

        // Check if we need to perform a DH ratchet step
        if state.theirDHPublicKey != message.header.dhPublicKey {
            // Skip any remaining messages in the current receiving chain
            try skipMessageKeys(until: message.header.previousChainCount)

            // Perform DH ratchet
            try dhRatchet(theirPublicKey: message.header.dhPublicKey)
        }

        // Skip messages if needed
        try skipMessageKeys(until: message.header.messageNumber)

        // Derive message key
        guard var chainKey = state.receivingChainKey else {
            throw SignalProtocolError.chainKeyExhausted
        }

        let (messageKey, nextChainKey) = Self.kdfChainKey(chainKey: chainKey)
        state.receivingChainKey = nextChainKey
        state.receivingMessageNumber += 1

        // Decrypt
        return try decryptWithKey(message: message, messageKey: messageKey)
    }

    // MARK: - DH Ratchet

    /// Perform a DH ratchet step when receiving a new DH public key
    private func dhRatchet(theirPublicKey: Data) throws {
        state.previousSendingChainLength = state.sendingMessageNumber
        state.sendingMessageNumber = 0
        state.receivingMessageNumber = 0
        state.theirDHPublicKey = theirPublicKey

        // Derive new receiving chain
        let dhOutput1 = try state.dhKeyPair.sharedSecret(with: theirPublicKey)
        let dhData1 = dhOutput1.withUnsafeBytes { Data($0) }
        let (rootKey1, receivingChainKey) = Self.kdfRootKey(
            rootKey: state.rootKey,
            dhOutput: dhData1
        )
        state.rootKey = rootKey1
        state.receivingChainKey = receivingChainKey

        // Generate new DH key pair
        state.dhKeyPair = KeyAgreementKeyPair()

        // Derive new sending chain
        let dhOutput2 = try state.dhKeyPair.sharedSecret(with: theirPublicKey)
        let dhData2 = dhOutput2.withUnsafeBytes { Data($0) }
        let (rootKey2, sendingChainKey) = Self.kdfRootKey(
            rootKey: state.rootKey,
            dhOutput: dhData2
        )
        state.rootKey = rootKey2
        state.sendingChainKey = sendingChainKey
    }

    // MARK: - Skipped Messages

    /// Try to decrypt using a skipped message key
    private func trySkippedMessageKeys(message: SignalMessage) throws -> Data? {
        guard let keysForDH = state.skippedMessageKeys[message.header.dhPublicKey],
              let messageKey = keysForDH[message.header.messageNumber] else {
            return nil
        }

        // Remove the used key
        state.skippedMessageKeys[message.header.dhPublicKey]?
            .removeValue(forKey: message.header.messageNumber)

        // Clean up empty dictionaries
        if state.skippedMessageKeys[message.header.dhPublicKey]?.isEmpty == true {
            state.skippedMessageKeys.removeValue(forKey: message.header.dhPublicKey)
        }

        return try decryptWithKey(message: message, messageKey: messageKey)
    }

    /// Skip message keys and store them for later out-of-order decryption
    private func skipMessageKeys(until messageNumber: UInt32) throws {
        guard let theirDHKey = state.theirDHPublicKey else { return }

        let skippedCount = messageNumber - state.receivingMessageNumber
        if skippedCount > DoubleRatchetConstants.maxSkippedMessages {
            throw SignalProtocolError.skippedMessageLimitExceeded
        }

        guard var chainKey = state.receivingChainKey else { return }

        while state.receivingMessageNumber < messageNumber {
            let (messageKey, nextChainKey) = Self.kdfChainKey(chainKey: chainKey)
            chainKey = nextChainKey

            // Store skipped key
            if state.skippedMessageKeys[theirDHKey] == nil {
                state.skippedMessageKeys[theirDHKey] = [:]
            }
            state.skippedMessageKeys[theirDHKey]?[state.receivingMessageNumber] = messageKey

            state.receivingMessageNumber += 1
        }

        state.receivingChainKey = chainKey
    }

    /// Decrypt a message with a specific message key
    private func decryptWithKey(message: SignalMessage, messageKey: Data) throws -> Data {
        // Serialize header for AAD
        let headerData = try JSONEncoder().encode(message.header)

        // Generate associated data
        let associatedData = generateAssociatedData(
            senderIdentityKey: theirIdentityKey,
            recipientIdentityKey: ourIdentityKey
        ) + headerData

        // Parse nonce from mac field
        let nonce = try ChaChaPoly.Nonce(data: message.mac)

        // Split ciphertext and tag
        let ciphertextLength = message.ciphertext.count - 16 // Tag is 16 bytes
        let ciphertext = message.ciphertext.prefix(ciphertextLength)
        let tag = message.ciphertext.suffix(16)

        // Create sealed box
        let sealedBox = try ChaChaPoly.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext,
            tag: tag
        )

        // Decrypt
        let symmetricKey = SymmetricKey(data: messageKey)
        return try ChaChaPoly.open(sealedBox, using: symmetricKey, authenticating: associatedData)
    }

    // MARK: - KDF Functions

    /// KDF for root key and chain key derivation
    private static func kdfRootKey(rootKey: Data, dhOutput: Data) -> (rootKey: Data, chainKey: Data) {
        let inputKey = SymmetricKey(data: rootKey)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: dhOutput,
            info: DoubleRatchetConstants.rootKeyInfo,
            outputByteCount: 64
        )

        var keyData = Data()
        derivedKey.withUnsafeBytes { keyData.append(contentsOf: $0) }

        let newRootKey = keyData.prefix(32)
        let chainKey = keyData.suffix(32)

        return (Data(newRootKey), Data(chainKey))
    }

    /// KDF for message key and next chain key derivation
    private static func kdfChainKey(chainKey: Data) -> (messageKey: Data, nextChainKey: Data) {
        // Message key: HMAC(chainKey, 0x01)
        let messageKeyInput = Data([DoubleRatchetConstants.messageKeyConstant])
        let messageKey = HMAC<SHA256>.authenticationCode(
            for: messageKeyInput,
            using: SymmetricKey(data: chainKey)
        )

        // Next chain key: HMAC(chainKey, 0x02)
        let chainKeyInput = Data([DoubleRatchetConstants.chainKeyConstant])
        let nextChainKey = HMAC<SHA256>.authenticationCode(
            for: chainKeyInput,
            using: SymmetricKey(data: chainKey)
        )

        return (
            Data(messageKey.withUnsafeBytes { Data($0) }),
            Data(nextChainKey.withUnsafeBytes { Data($0) })
        )
    }

    // MARK: - State Access

    /// Get the current state (for persistence)
    func getState() -> RatchetState {
        state
    }

    /// Get our current DH public key
    func getOurDHPublicKey() -> Data {
        state.dhKeyPair.publicKey
    }
}

// MARK: - Symmetric Ratchet

/// A simple symmetric-key ratchet for cases where DH ratchet is not needed
struct SymmetricRatchet {
    private var chainKey: Data
    private var messageNumber: UInt32 = 0

    init(chainKey: Data) {
        self.chainKey = chainKey
    }

    /// Get the next message key and advance the ratchet
    mutating func nextMessageKey() -> (messageKey: Data, messageNumber: UInt32) {
        // Message key: HMAC(chainKey, 0x01)
        let messageKeyInput = Data([DoubleRatchetConstants.messageKeyConstant])
        let messageKey = HMAC<SHA256>.authenticationCode(
            for: messageKeyInput,
            using: SymmetricKey(data: chainKey)
        )

        // Next chain key: HMAC(chainKey, 0x02)
        let chainKeyInput = Data([DoubleRatchetConstants.chainKeyConstant])
        let nextChainKey = HMAC<SHA256>.authenticationCode(
            for: chainKeyInput,
            using: SymmetricKey(data: chainKey)
        )

        chainKey = Data(nextChainKey.withUnsafeBytes { Data($0) })
        let currentNumber = messageNumber
        messageNumber += 1

        return (Data(messageKey.withUnsafeBytes { Data($0) }), currentNumber)
    }
}
