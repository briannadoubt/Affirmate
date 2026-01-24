//
//  SignalProtocolTypes.swift
//  Affirmate
//
//  Signal Protocol compliant key types and structures.
//

import CryptoKit
import Foundation

// MARK: - Signal Protocol Errors

enum SignalProtocolError: LocalizedError {
    case invalidKeyData
    case sessionNotFound
    case invalidPreKeyBundle
    case signatureVerificationFailed
    case decryptionFailed
    case messageCounterMismatch
    case skippedMessageLimitExceeded
    case invalidMessageFormat
    case noOneTimePreKeyAvailable
    case chainKeyExhausted

    var errorDescription: String? {
        switch self {
        case .invalidKeyData:
            return "Invalid key data format"
        case .sessionNotFound:
            return "No session found for this recipient"
        case .invalidPreKeyBundle:
            return "Invalid PreKey bundle"
        case .signatureVerificationFailed:
            return "Signature verification failed on PreKey bundle"
        case .decryptionFailed:
            return "Failed to decrypt message"
        case .messageCounterMismatch:
            return "Message counter mismatch - possible replay attack"
        case .skippedMessageLimitExceeded:
            return "Too many skipped messages"
        case .invalidMessageFormat:
            return "Invalid message format"
        case .noOneTimePreKeyAvailable:
            return "No one-time PreKey available"
        case .chainKeyExhausted:
            return "Chain key exhausted, need new DH ratchet"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidKeyData:
            return "Regenerate the cryptographic keys"
        case .sessionNotFound:
            return "Establish a new session before sending messages"
        case .invalidPreKeyBundle:
            return "Request an updated PreKey bundle from the server"
        case .signatureVerificationFailed:
            return "The PreKey bundle may be corrupted or from an untrusted source"
        case .decryptionFailed:
            return "The message may be corrupted, tampered with, or from a different session"
        case .messageCounterMismatch:
            return "Discard the message as it may be a replay attack"
        case .skippedMessageLimitExceeded:
            return "Too many messages were lost. Consider establishing a new session"
        case .invalidMessageFormat:
            return "The message format is invalid. Check protocol version compatibility"
        case .noOneTimePreKeyAvailable:
            return "Upload more one-time PreKeys to the server"
        case .chainKeyExhausted:
            return "This is an internal error. The ratchet should perform a DH step automatically"
        }
    }
}

// MARK: - Identity Key Pair

/// Long-term identity key pair used for authentication.
/// This key pair is generated once and persists for the lifetime of the account.
struct IdentityKeyPair: Codable {
    let privateKey: Data
    let publicKey: Data
    let agreementKeyPair: KeyAgreementKeyPair

    init() {
        let key = Curve25519.Signing.PrivateKey()
        self.privateKey = key.rawRepresentation
        self.publicKey = key.publicKey.rawRepresentation
        self.agreementKeyPair = KeyAgreementKeyPair()
    }

    init(privateKey: Data, publicKey: Data, agreementKeyPair: KeyAgreementKeyPair) {
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.agreementKeyPair = agreementKeyPair
    }

    func signingPrivateKey() throws -> Curve25519.Signing.PrivateKey {
        try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
    }

    func signingPublicKey() throws -> Curve25519.Signing.PublicKey {
        try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
    }

    /// Sign data with the identity key
    func sign(_ data: Data) throws -> Data {
        let key = try signingPrivateKey()
        return try key.signature(for: data)
    }

    /// Verify a signature from a public identity key
    static func verify(signature: Data, for data: Data, from publicKey: Data) throws -> Bool {
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        return key.isValidSignature(signature, for: data)
    }

    private enum CodingKeys: String, CodingKey {
        case privateKey
        case publicKey
        case agreementKeyPair
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.privateKey = try container.decode(Data.self, forKey: .privateKey)
        self.publicKey = try container.decode(Data.self, forKey: .publicKey)
        if let agreementKeyPair = try container.decodeIfPresent(KeyAgreementKeyPair.self, forKey: .agreementKeyPair) {
            self.agreementKeyPair = agreementKeyPair
        } else {
            self.agreementKeyPair = KeyAgreementKeyPair()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(privateKey, forKey: .privateKey)
        try container.encode(publicKey, forKey: .publicKey)
        try container.encode(agreementKeyPair, forKey: .agreementKeyPair)
    }
}

// MARK: - Key Agreement Key Pair

/// Curve25519 key pair for Diffie-Hellman key agreement
struct KeyAgreementKeyPair: Codable {
    let privateKey: Data
    let publicKey: Data

    init() {
        let key = Curve25519.KeyAgreement.PrivateKey()
        self.privateKey = key.rawRepresentation
        self.publicKey = key.publicKey.rawRepresentation
    }

    init(privateKey: Data, publicKey: Data) {
        self.privateKey = privateKey
        self.publicKey = publicKey
    }

    func agreementPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
    }

    func agreementPublicKey() throws -> Curve25519.KeyAgreement.PublicKey {
        try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKey)
    }

    /// Perform Diffie-Hellman key agreement
    func sharedSecret(with theirPublicKey: Data) throws -> SharedSecret {
        let ourKey = try agreementPrivateKey()
        let theirKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: theirPublicKey)
        return try ourKey.sharedSecretFromKeyAgreement(with: theirKey)
    }
}

// MARK: - Signed PreKey

/// Medium-term signed PreKey.
/// Rotated periodically (e.g., weekly) and signed by the identity key.
struct SignedPreKey: Codable {
    let id: UInt32
    let keyPair: KeyAgreementKeyPair
    let signature: Data
    let timestamp: Date

    init(id: UInt32, identityKey: IdentityKeyPair) throws {
        self.id = id
        self.keyPair = KeyAgreementKeyPair()
        self.timestamp = Date()
        // Sign the public key with the identity key
        self.signature = try identityKey.sign(keyPair.publicKey)
    }

    init(id: UInt32, keyPair: KeyAgreementKeyPair, signature: Data, timestamp: Date) {
        self.id = id
        self.keyPair = keyPair
        self.signature = signature
        self.timestamp = timestamp
    }

    /// Verify the signature on this signed PreKey
    func verify(with identityPublicKey: Data) throws -> Bool {
        try IdentityKeyPair.verify(signature: signature, for: keyPair.publicKey, from: identityPublicKey)
    }
}

// MARK: - One-Time PreKey

/// Ephemeral one-time PreKey for forward secrecy.
/// Each key can only be used once.
struct OneTimePreKey: Codable {
    let id: UInt32
    let keyPair: KeyAgreementKeyPair

    init(id: UInt32) {
        self.id = id
        self.keyPair = KeyAgreementKeyPair()
    }

    init(id: UInt32, keyPair: KeyAgreementKeyPair) {
        self.id = id
        self.keyPair = keyPair
    }
}

// MARK: - PreKey Bundle

/// Public PreKey bundle published to the server.
/// Used by others to establish a session.
struct PreKeyBundle: Codable {
    /// The user's public identity key
    let identityKey: Data
    /// The user's public identity agreement key
    let identityAgreementKey: Data
    /// The signed PreKey ID
    let signedPreKeyId: UInt32
    /// The signed PreKey public key
    let signedPreKey: Data
    /// Signature on the signed PreKey
    let signedPreKeySignature: Data
    /// Optional one-time PreKey ID
    let oneTimePreKeyId: UInt32?
    /// Optional one-time PreKey public key
    let oneTimePreKey: Data?

    /// Verify the signed PreKey signature
    func verifySignature() throws -> Bool {
        try IdentityKeyPair.verify(
            signature: signedPreKeySignature,
            for: signedPreKey,
            from: identityKey
        )
    }
}

// MARK: - Message Header

/// Header included with each encrypted message.
/// Contains the DH ratchet public key and message counters.
struct MessageHeader: Codable {
    /// Current DH ratchet public key
    let dhPublicKey: Data
    /// Previous chain message count (for out-of-order message handling)
    let previousChainCount: UInt32
    /// Message number in current chain
    let messageNumber: UInt32
}

// MARK: - Signal Protocol Message

/// Complete encrypted message with header and ciphertext
struct SignalMessage: Codable {
    /// Message header containing DH key and counters
    let header: MessageHeader
    /// Encrypted message content
    let ciphertext: Data
    /// MAC for authentication
    let mac: Data

    /// Serialize the message for transmission
    func serialize() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Deserialize a message from data
    static func deserialize(from data: Data) throws -> SignalMessage {
        try JSONDecoder().decode(SignalMessage.self, from: data)
    }
}

// MARK: - PreKey Signal Message

/// Initial message when establishing a new session using X3DH
struct PreKeySignalMessage: Codable {
    /// Sender's identity public key
    let identityKey: Data
    /// Sender's identity agreement public key
    let identityAgreementKey: Data
    /// Sender's ephemeral public key (used in X3DH)
    let ephemeralKey: Data
    /// ID of the signed PreKey used
    let signedPreKeyId: UInt32
    /// ID of the one-time PreKey used (if any)
    let oneTimePreKeyId: UInt32?
    /// The actual encrypted message
    let message: SignalMessage

    private enum CodingKeys: String, CodingKey {
        case identityKey
        case identityAgreementKey
        case ephemeralKey
        case signedPreKeyId
        case oneTimePreKeyId
        case message
    }

    init(
        identityKey: Data,
        identityAgreementKey: Data,
        ephemeralKey: Data,
        signedPreKeyId: UInt32,
        oneTimePreKeyId: UInt32?,
        message: SignalMessage
    ) {
        self.identityKey = identityKey
        self.identityAgreementKey = identityAgreementKey
        self.ephemeralKey = ephemeralKey
        self.signedPreKeyId = signedPreKeyId
        self.oneTimePreKeyId = oneTimePreKeyId
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let identityKey = try container.decode(Data.self, forKey: .identityKey)
        let identityAgreementKey = try container.decodeIfPresent(Data.self, forKey: .identityAgreementKey)
        self.identityKey = identityKey
        self.identityAgreementKey = identityAgreementKey ?? identityKey
        self.ephemeralKey = try container.decode(Data.self, forKey: .ephemeralKey)
        self.signedPreKeyId = try container.decode(UInt32.self, forKey: .signedPreKeyId)
        self.oneTimePreKeyId = try container.decodeIfPresent(UInt32.self, forKey: .oneTimePreKeyId)
        self.message = try container.decode(SignalMessage.self, forKey: .message)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identityKey, forKey: .identityKey)
        try container.encode(identityAgreementKey, forKey: .identityAgreementKey)
        try container.encode(ephemeralKey, forKey: .ephemeralKey)
        try container.encode(signedPreKeyId, forKey: .signedPreKeyId)
        try container.encodeIfPresent(oneTimePreKeyId, forKey: .oneTimePreKeyId)
        try container.encode(message, forKey: .message)
    }

    /// Serialize the message for transmission
    func serialize() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Deserialize a message from data
    static func deserialize(from data: Data) throws -> PreKeySignalMessage {
        try JSONDecoder().decode(PreKeySignalMessage.self, from: data)
    }
}

// MARK: - Associated Data

/// Generate associated data for AEAD encryption
/// This binds the ciphertext to both parties' identity keys
func generateAssociatedData(
    senderIdentityKey: Data,
    recipientIdentityKey: Data
) -> Data {
    senderIdentityKey + recipientIdentityKey
}
