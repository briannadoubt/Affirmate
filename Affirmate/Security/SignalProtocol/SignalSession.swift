//
//  SignalSession.swift
//  Affirmate
//
//  Signal Protocol session management.
//  Handles session establishment, message encryption/decryption, and state persistence.
//

import CryptoKit
import Foundation
import KeychainAccess

// MARK: - Session Identifier

/// Unique identifier for a Signal session between two parties
struct SessionIdentifier: Codable, Hashable, CustomStringConvertible {
    let recipientId: UUID
    let deviceId: UInt32

    var description: String {
        "\(recipientId.uuidString):\(deviceId)"
    }

    init(recipientId: UUID, deviceId: UInt32 = 1) {
        self.recipientId = recipientId
        self.deviceId = deviceId
    }
}

// MARK: - Session Record

/// A record containing the session state and metadata
struct SessionRecord: Codable {
    /// The session identifier
    let identifier: SessionIdentifier
    /// The Double Ratchet state
    var ratchetState: RatchetState
    /// Our identity public key used in this session
    let ourIdentityKey: Data
    /// Their identity public key
    let theirIdentityKey: Data
    /// Timestamp when session was created
    let createdAt: Date
    /// Timestamp of last activity
    var lastActivityAt: Date
    /// Whether we initiated the session
    let isInitiator: Bool
}

// MARK: - Signal Session Manager

/// Manages Signal Protocol sessions for encrypted communication.
actor SignalSessionManager {

    /// Storage for session records
    private var sessions: [SessionIdentifier: SessionRecord] = [:]
    /// Active Double Ratchet instances
    private var ratchets: [SessionIdentifier: DoubleRatchet] = [:]

    /// Our identity key pair
    private let identityKeyPair: IdentityKeyPair
    /// PreKey manager
    private let preKeyManager: PreKeyManager
    /// X3DH instance
    private let x3dh: X3DH
    /// Keychain for persistence
    private let keychain: Keychain

    // MARK: - Initialization

    init(
        identityKeyPair: IdentityKeyPair,
        preKeyManager: PreKeyManager,
        keychain: Keychain = AffirmateKeychain.chat
    ) {
        self.identityKeyPair = identityKeyPair
        self.preKeyManager = preKeyManager
        self.x3dh = X3DH()
        self.keychain = keychain
    }

    // MARK: - Session Establishment

    /// Establish a new session with a recipient using their PreKey bundle.
    /// This is called by the initiator (Alice).
    ///
    /// - Parameters:
    ///   - recipientId: The recipient's user ID
    ///   - deviceId: The recipient's device ID
    ///   - preKeyBundle: The recipient's PreKey bundle
    /// - Returns: The established session and initial message components
    func establishSession(
        recipientId: UUID,
        deviceId: UInt32 = 1,
        preKeyBundle: PreKeyBundle
    ) async throws -> (session: SessionRecord, ephemeralKey: Data, usedOneTimePreKeyId: UInt32?) {
        let sessionId = SessionIdentifier(recipientId: recipientId, deviceId: deviceId)

        // Perform X3DH key agreement
        let x3dhResult = try await x3dh.initiateKeyAgreement(
            identityKeyPair: identityKeyPair,
            preKeyBundle: preKeyBundle
        )

        // Initialize Double Ratchet as initiator
        let ratchet = try DoubleRatchet(
            asInitiator: x3dhResult.sharedSecret,
            theirSignedPreKey: preKeyBundle.signedPreKey,
            ourIdentityKey: identityKeyPair.publicKey,
            theirIdentityKey: preKeyBundle.identityKey
        )

        // Create session record
        let session = SessionRecord(
            identifier: sessionId,
            ratchetState: await ratchet.getState(),
            ourIdentityKey: identityKeyPair.publicKey,
            theirIdentityKey: preKeyBundle.identityKey,
            createdAt: Date(),
            lastActivityAt: Date(),
            isInitiator: true
        )

        // Store session
        sessions[sessionId] = session
        ratchets[sessionId] = ratchet

        return (session, x3dhResult.ephemeralKeyPair.publicKey, x3dhResult.usedOneTimePreKeyId)
    }

    /// Process an incoming PreKey message to establish a session.
    /// This is called by the responder (Bob).
    ///
    /// - Parameters:
    ///   - senderId: The sender's user ID
    ///   - deviceId: The sender's device ID
    ///   - preKeyMessage: The incoming PreKey message
    /// - Returns: The decrypted plaintext
    func processPreKeyMessage(
        senderId: UUID,
        deviceId: UInt32 = 1,
        preKeyMessage: PreKeySignalMessage
    ) async throws -> Data {
        let sessionId = SessionIdentifier(recipientId: senderId, deviceId: deviceId)

        // Get our signed PreKey
        guard let signedPreKey = await preKeyManager.getSignedPreKey(),
              signedPreKey.id == preKeyMessage.signedPreKeyId else {
            throw SignalProtocolError.invalidPreKeyBundle
        }

        // Get and consume the one-time PreKey if used
        var oneTimePreKey: OneTimePreKey?
        if let otpkId = preKeyMessage.oneTimePreKeyId {
            oneTimePreKey = await preKeyManager.consumeOneTimePreKey(id: otpkId)
        }

        // Perform X3DH as responder
        let sharedSecret = try await x3dh.respondToKeyAgreement(
            identityKeyPair: identityKeyPair,
            signedPreKey: signedPreKey,
            oneTimePreKey: oneTimePreKey,
            theirIdentityAgreementKey: preKeyMessage.identityAgreementKey,
            theirEphemeralKey: preKeyMessage.ephemeralKey
        )

        // Initialize Double Ratchet as responder
        let ratchet = DoubleRatchet(
            asResponder: sharedSecret,
            ourSignedPreKey: signedPreKey,
            ourIdentityKey: identityKeyPair.publicKey,
            theirIdentityKey: preKeyMessage.identityKey
        )

        // Decrypt the message
        let plaintext = try await ratchet.decrypt(preKeyMessage.message)

        // Create session record
        let session = SessionRecord(
            identifier: sessionId,
            ratchetState: await ratchet.getState(),
            ourIdentityKey: identityKeyPair.publicKey,
            theirIdentityKey: preKeyMessage.identityKey,
            createdAt: Date(),
            lastActivityAt: Date(),
            isInitiator: false
        )

        // Store session
        sessions[sessionId] = session
        ratchets[sessionId] = ratchet

        return plaintext
    }

    // MARK: - Message Encryption/Decryption

    /// Encrypt a message for a recipient.
    ///
    /// - Parameters:
    ///   - plaintext: The message to encrypt
    ///   - recipientId: The recipient's user ID
    ///   - deviceId: The recipient's device ID
    /// - Returns: The encrypted message (either PreKeySignalMessage or SignalMessage)
    func encryptMessage(
        _ plaintext: Data,
        to recipientId: UUID,
        deviceId: UInt32 = 1
    ) async throws -> EncryptedMessageContainer {
        let sessionId = SessionIdentifier(recipientId: recipientId, deviceId: deviceId)

        guard let session = sessions[sessionId],
              let ratchet = ratchets[sessionId] else {
            throw SignalProtocolError.sessionNotFound
        }

        let message = try await ratchet.encrypt(plaintext)

        // Update session state
        var updatedSession = session
        updatedSession.ratchetState = await ratchet.getState()
        updatedSession.lastActivityAt = Date()
        sessions[sessionId] = updatedSession

        return .signalMessage(message)
    }

    /// Encrypt a message for a new session (creates PreKeySignalMessage).
    ///
    /// - Parameters:
    ///   - plaintext: The message to encrypt
    ///   - recipientId: The recipient's user ID
    ///   - deviceId: The recipient's device ID
    ///   - preKeyBundle: The recipient's PreKey bundle
    /// - Returns: The PreKey message for initial session establishment
    func encryptFirstMessage(
        _ plaintext: Data,
        to recipientId: UUID,
        deviceId: UInt32 = 1,
        preKeyBundle: PreKeyBundle
    ) async throws -> PreKeySignalMessage {
        // Establish session
        let (session, ephemeralKey, usedOTPKId) = try await establishSession(
            recipientId: recipientId,
            deviceId: deviceId,
            preKeyBundle: preKeyBundle
        )

        // Encrypt the message
        let sessionId = SessionIdentifier(recipientId: recipientId, deviceId: deviceId)
        guard let ratchet = ratchets[sessionId] else {
            throw SignalProtocolError.sessionNotFound
        }

        let message = try await ratchet.encrypt(plaintext)

        // Create PreKey message
        return PreKeySignalMessage(
            identityKey: identityKeyPair.publicKey,
            identityAgreementKey: identityKeyPair.agreementKeyPair.publicKey,
            ephemeralKey: ephemeralKey,
            signedPreKeyId: preKeyBundle.signedPreKeyId,
            oneTimePreKeyId: usedOTPKId,
            message: message
        )
    }

    /// Decrypt a message from a sender.
    ///
    /// - Parameters:
    ///   - container: The encrypted message container
    ///   - senderId: The sender's user ID
    ///   - deviceId: The sender's device ID
    /// - Returns: The decrypted plaintext
    func decryptMessage(
        _ container: EncryptedMessageContainer,
        from senderId: UUID,
        deviceId: UInt32 = 1
    ) async throws -> Data {
        switch container {
        case .preKeyMessage(let preKeyMessage):
            return try await processPreKeyMessage(
                senderId: senderId,
                deviceId: deviceId,
                preKeyMessage: preKeyMessage
            )

        case .signalMessage(let message):
            let sessionId = SessionIdentifier(recipientId: senderId, deviceId: deviceId)

            guard let session = sessions[sessionId],
                  let ratchet = ratchets[sessionId] else {
                throw SignalProtocolError.sessionNotFound
            }

            let plaintext = try await ratchet.decrypt(message)

            // Update session state
            var updatedSession = session
            updatedSession.ratchetState = await ratchet.getState()
            updatedSession.lastActivityAt = Date()
            sessions[sessionId] = updatedSession

            return plaintext
        }
    }

    // MARK: - Session Management

    /// Check if a session exists for a recipient
    func hasSession(for recipientId: UUID, deviceId: UInt32 = 1) -> Bool {
        let sessionId = SessionIdentifier(recipientId: recipientId, deviceId: deviceId)
        return sessions[sessionId] != nil
    }

    /// Get session record for a recipient
    func getSession(for recipientId: UUID, deviceId: UInt32 = 1) -> SessionRecord? {
        let sessionId = SessionIdentifier(recipientId: recipientId, deviceId: deviceId)
        return sessions[sessionId]
    }

    /// Delete a session
    func deleteSession(for recipientId: UUID, deviceId: UInt32 = 1) {
        let sessionId = SessionIdentifier(recipientId: recipientId, deviceId: deviceId)
        sessions.removeValue(forKey: sessionId)
        ratchets.removeValue(forKey: sessionId)
    }

    /// Delete all sessions for a recipient (all devices)
    func deleteAllSessions(for recipientId: UUID) {
        let sessionIds = sessions.keys.filter { $0.recipientId == recipientId }
        for sessionId in sessionIds {
            sessions.removeValue(forKey: sessionId)
            ratchets.removeValue(forKey: sessionId)
        }
    }

    /// Get all session identifiers
    func getAllSessionIdentifiers() -> [SessionIdentifier] {
        Array(sessions.keys)
    }

    // MARK: - Persistence

    /// Save all sessions to keychain
    func saveToKeychain() throws {
        let encoder = JSONEncoder()
        for (sessionId, session) in sessions {
            let key = "signal.session.\(sessionId.description)"
            let data = try encoder.encode(session)
            keychain[data: key] = data
        }
    }

    /// Load sessions from keychain
    func loadFromKeychain() throws {
        let decoder = JSONDecoder()

        // Get all session keys from keychain
        let allItems = keychain.allItems()
        for item in allItems {
            guard let key = item["key"] as? String,
                  key.hasPrefix("signal.session."),
                  let data = try keychain.getData(key) else {
                continue
            }

            let session = try decoder.decode(SessionRecord.self, from: data)

            // Restore session
            sessions[session.identifier] = session

            // Restore ratchet
            let ratchet = DoubleRatchet(
                state: session.ratchetState,
                ourIdentityKey: session.ourIdentityKey,
                theirIdentityKey: session.theirIdentityKey
            )
            ratchets[session.identifier] = ratchet
        }
    }

    /// Get our public identity key
    func getIdentityPublicKey() -> Data {
        identityKeyPair.publicKey
    }
}

// MARK: - Encrypted Message Container

/// Container for encrypted messages (either initial PreKey or regular Signal message)
enum EncryptedMessageContainer: Codable {
    case preKeyMessage(PreKeySignalMessage)
    case signalMessage(SignalMessage)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum MessageType: String, Codable {
        case preKey
        case signal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .preKey:
            let payload = try container.decode(PreKeySignalMessage.self, forKey: .payload)
            self = .preKeyMessage(payload)
        case .signal:
            let payload = try container.decode(SignalMessage.self, forKey: .payload)
            self = .signalMessage(payload)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .preKeyMessage(let message):
            try container.encode(MessageType.preKey, forKey: .type)
            try container.encode(message, forKey: .payload)
        case .signalMessage(let message):
            try container.encode(MessageType.signal, forKey: .type)
            try container.encode(message, forKey: .payload)
        }
    }

    /// Serialize for transmission
    func serialize() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Deserialize from data
    static func deserialize(from data: Data) throws -> EncryptedMessageContainer {
        try JSONDecoder().decode(EncryptedMessageContainer.self, from: data)
    }
}
