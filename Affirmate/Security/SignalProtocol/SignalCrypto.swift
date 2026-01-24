//
//  SignalCrypto.swift
//  Affirmate
//
//  High-level Signal Protocol encryption API.
//  This replaces the previous AffirmateCrypto with Signal Protocol compliant encryption.
//

import AffirmateShared
import CryptoKit
import Foundation
import KeychainAccess

// MARK: - Signal Crypto Errors

enum SignalCryptoError: LocalizedError {
    case notInitialized
    case sessionNotFound(UUID)
    case preKeyBundleNotFound(UUID)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Signal Protocol not initialized"
        case .sessionNotFound(let userId):
            return "No session found for user \(userId)"
        case .preKeyBundleNotFound(let userId):
            return "PreKey bundle not found for user \(userId)"
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            return "Decryption failed: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notInitialized:
            return "Call SignalCrypto.shared.initialize() before performing encryption operations"
        case .sessionNotFound:
            return "Establish a new session with the recipient by fetching their PreKey bundle"
        case .preKeyBundleNotFound:
            return "The recipient needs to upload their Signal keys to the server"
        case .encryptionFailed, .decryptionFailed:
            return "Verify that both parties have valid sessions and matching protocol versions"
        case .networkError:
            return "Check network connectivity and retry the operation"
        }
    }
}

// MARK: - Signal Crypto

/// High-level Signal Protocol encryption manager.
/// Provides a simple API for encrypting and decrypting messages.
actor SignalCrypto {

    private var protocolStore: SignalProtocolStore?
    private var sessionManager: SignalSessionManager?
    private var isInitialized = false

    /// Shared instance
    static let shared = SignalCrypto()

    private init() {}

    // MARK: - Initialization

    /// Initialize the Signal Protocol.
    /// Must be called before any encryption/decryption operations.
    func initialize() async throws {
        let store = SignalProtocolStore()
        try await store.initialize()
        self.protocolStore = store
        self.sessionManager = try store.createSessionManager()
        self.isInitialized = true
    }

    /// Check if initialized
    func ensureInitialized() throws {
        guard isInitialized, protocolStore != nil, sessionManager != nil else {
            throw SignalCryptoError.notInitialized
        }
    }

    // MARK: - Key Management

    /// Get the public keys to upload to the server
    func getPublicKeysForUpload() async throws -> SignalKeysUpload {
        try ensureInitialized()
        guard let store = protocolStore else {
            throw SignalCryptoError.notInitialized
        }

        let keys = try await store.getPublicKeys()

        return SignalKeysUpload(
            registrationId: keys.registrationId,
            identityKey: keys.identityKey,
            identityAgreementKey: keys.identityAgreementKey,
            signedPreKey: SignedPreKeyUpload(
                id: keys.signedPreKeyId,
                publicKey: keys.signedPreKey,
                signature: keys.signedPreKeySignature
            ),
            oneTimePreKeys: keys.oneTimePreKeys.map {
                OneTimePreKeyUpload(id: $0.id, publicKey: $0.key)
            }
        )
    }

    /// Create additional one-time PreKeys for upload
    func generateAdditionalPreKeys(count: Int) async throws -> [OneTimePreKeyUpload] {
        try ensureInitialized()
        guard let store = protocolStore else {
            throw SignalCryptoError.notInitialized
        }

        let preKeyManager = await store.getPreKeyManager()
        let newKeys = await preKeyManager.generateOneTimePreKeys(count: count)

        return newKeys.map {
            OneTimePreKeyUpload(id: $0.id, publicKey: $0.keyPair.publicKey)
        }
    }

    /// Rotate the signed PreKey
    func rotateSignedPreKey() async throws -> SignedPreKeyUpload {
        try ensureInitialized()
        guard let store = protocolStore else {
            throw SignalCryptoError.notInitialized
        }

        try await store.rotateSignedPreKey()

        let keys = try await store.getPublicKeys()
        return SignedPreKeyUpload(
            id: keys.signedPreKeyId,
            publicKey: keys.signedPreKey,
            signature: keys.signedPreKeySignature
        )
    }

    // MARK: - Session Management

    /// Check if we have an established session with a user
    func hasSession(with userId: UUID) async throws -> Bool {
        try ensureInitialized()
        guard let manager = sessionManager else {
            throw SignalCryptoError.notInitialized
        }
        return await manager.hasSession(for: userId)
    }

    /// Establish a session using a PreKey bundle from the server
    func establishSession(with userId: UUID, preKeyBundle: SignalPreKeyBundle) async throws {
        try ensureInitialized()
        guard let manager = sessionManager else {
            throw SignalCryptoError.notInitialized
        }

        // Convert to internal PreKey bundle format
        let bundle = PreKeyBundle(
            identityKey: preKeyBundle.identityKey,
            identityAgreementKey: preKeyBundle.identityAgreementKey,
            signedPreKeyId: preKeyBundle.signedPreKeyId,
            signedPreKey: preKeyBundle.signedPreKey,
            signedPreKeySignature: preKeyBundle.signedPreKeySignature,
            oneTimePreKeyId: preKeyBundle.oneTimePreKeyId,
            oneTimePreKey: preKeyBundle.oneTimePreKey
        )

        _ = try await manager.establishSession(
            recipientId: userId,
            preKeyBundle: bundle
        )
    }

    // MARK: - Encryption

    /// Encrypt a message for a recipient.
    /// If no session exists, this will fail - use encryptFirstMessage instead.
    func encrypt(_ plaintext: Data, for recipientId: UUID) async throws -> SignalMessageContainer {
        try ensureInitialized()
        guard let manager = sessionManager else {
            throw SignalCryptoError.notInitialized
        }

        guard await manager.hasSession(for: recipientId) else {
            throw SignalCryptoError.sessionNotFound(recipientId)
        }

        let encrypted = try await manager.encryptMessage(plaintext, to: recipientId)

        // Convert to shared message format
        switch encrypted {
        case .preKeyMessage(let msg):
            return .preKeyMessage(SignalPreKeyMessage(
                registrationId: 0, // Will be filled by session manager
                identityKey: msg.identityKey,
                identityAgreementKey: msg.identityAgreementKey,
                ephemeralKey: msg.ephemeralKey,
                signedPreKeyId: msg.signedPreKeyId,
                oneTimePreKeyId: msg.oneTimePreKeyId,
                message: SignalEncryptedMessage(
                    header: SignalMessageHeader(
                        dhPublicKey: msg.message.header.dhPublicKey,
                        previousChainCount: msg.message.header.previousChainCount,
                        messageNumber: msg.message.header.messageNumber
                    ),
                    ciphertext: msg.message.ciphertext,
                    mac: msg.message.mac
                )
            ))
        case .signalMessage(let msg):
            return .signalMessage(SignalEncryptedMessage(
                header: SignalMessageHeader(
                    dhPublicKey: msg.header.dhPublicKey,
                    previousChainCount: msg.header.previousChainCount,
                    messageNumber: msg.header.messageNumber
                ),
                ciphertext: msg.ciphertext,
                mac: msg.mac
            ))
        }
    }

    /// Encrypt a message for a new session (first message to a recipient).
    func encryptFirstMessage(
        _ plaintext: Data,
        for recipientId: UUID,
        preKeyBundle: SignalPreKeyBundle
    ) async throws -> SignalMessageContainer {
        try ensureInitialized()
        guard let manager = sessionManager,
              let store = protocolStore else {
            throw SignalCryptoError.notInitialized
        }

        // Convert to internal PreKey bundle format
        let bundle = PreKeyBundle(
            identityKey: preKeyBundle.identityKey,
            identityAgreementKey: preKeyBundle.identityAgreementKey,
            signedPreKeyId: preKeyBundle.signedPreKeyId,
            signedPreKey: preKeyBundle.signedPreKey,
            signedPreKeySignature: preKeyBundle.signedPreKeySignature,
            oneTimePreKeyId: preKeyBundle.oneTimePreKeyId,
            oneTimePreKey: preKeyBundle.oneTimePreKey
        )

        let preKeyMessage = try await manager.encryptFirstMessage(
            plaintext,
            to: recipientId,
            preKeyBundle: bundle
        )

        let registrationId = try await store.getRegistrationId()

        return .preKeyMessage(SignalPreKeyMessage(
            registrationId: registrationId,
            identityKey: preKeyMessage.identityKey,
            identityAgreementKey: preKeyMessage.identityAgreementKey,
            ephemeralKey: preKeyMessage.ephemeralKey,
            signedPreKeyId: preKeyMessage.signedPreKeyId,
            oneTimePreKeyId: preKeyMessage.oneTimePreKeyId,
            message: SignalEncryptedMessage(
                header: SignalMessageHeader(
                    dhPublicKey: preKeyMessage.message.header.dhPublicKey,
                    previousChainCount: preKeyMessage.message.header.previousChainCount,
                    messageNumber: preKeyMessage.message.header.messageNumber
                ),
                ciphertext: preKeyMessage.message.ciphertext,
                mac: preKeyMessage.message.mac
            )
        ))
    }

    /// Encrypt a string message
    func encrypt(_ message: String, for recipientId: UUID) async throws -> SignalMessageContainer {
        guard let data = message.data(using: .utf8) else {
            throw SignalCryptoError.encryptionFailed("Failed to encode message as UTF-8")
        }
        return try await encrypt(data, for: recipientId)
    }

    /// Encrypt a string message for a new session
    func encryptFirstMessage(
        _ message: String,
        for recipientId: UUID,
        preKeyBundle: SignalPreKeyBundle
    ) async throws -> SignalMessageContainer {
        guard let data = message.data(using: .utf8) else {
            throw SignalCryptoError.encryptionFailed("Failed to encode message as UTF-8")
        }
        return try await encryptFirstMessage(data, for: recipientId, preKeyBundle: preKeyBundle)
    }

    // MARK: - Decryption

    /// Decrypt a message from a sender.
    func decrypt(_ container: SignalMessageContainer, from senderId: UUID) async throws -> Data {
        try ensureInitialized()
        guard let manager = sessionManager,
              let store = protocolStore else {
            throw SignalCryptoError.notInitialized
        }

        // Convert from shared message format
        let internalContainer: EncryptedMessageContainer
        let oneTimePreKeyIdToConsume: UInt32?

        switch container {
        case .preKeyMessage(let msg):
            internalContainer = .preKeyMessage(PreKeySignalMessage(
                identityKey: msg.identityKey,
                identityAgreementKey: msg.identityAgreementKey,
                ephemeralKey: msg.ephemeralKey,
                signedPreKeyId: msg.signedPreKeyId,
                oneTimePreKeyId: msg.oneTimePreKeyId,
                message: SignalMessage(
                    header: MessageHeader(
                        dhPublicKey: msg.message.header.dhPublicKey,
                        previousChainCount: msg.message.header.previousChainCount,
                        messageNumber: msg.message.header.messageNumber
                    ),
                    ciphertext: msg.message.ciphertext,
                    mac: msg.message.mac
                )
            ))
            oneTimePreKeyIdToConsume = msg.oneTimePreKeyId

        case .signalMessage(let msg):
            internalContainer = .signalMessage(SignalMessage(
                header: MessageHeader(
                    dhPublicKey: msg.header.dhPublicKey,
                    previousChainCount: msg.header.previousChainCount,
                    messageNumber: msg.header.messageNumber
                ),
                ciphertext: msg.ciphertext,
                mac: msg.mac
            ))
            oneTimePreKeyIdToConsume = nil
        }

        let plaintext = try await manager.decryptMessage(internalContainer, from: senderId)

        if let otpkId = oneTimePreKeyIdToConsume {
            try await store.consumeOneTimePreKey(id: otpkId)
        }

        return plaintext
    }

    /// Decrypt a message and return it as a string
    func decryptToString(_ container: SignalMessageContainer, from senderId: UUID) async throws -> String {
        let data = try await decrypt(container, from: senderId)
        guard let string = String(data: data, encoding: .utf8) else {
            throw SignalCryptoError.decryptionFailed("Failed to decode message as UTF-8")
        }
        return string
    }

    // MARK: - Cleanup

    /// Delete session with a user
    func deleteSession(with userId: UUID) async throws {
        try ensureInitialized()
        guard let manager = sessionManager else {
            throw SignalCryptoError.notInitialized
        }
        await manager.deleteSession(for: userId)
    }

    /// Reset all Signal Protocol state (careful - this invalidates all sessions!)
    func reset() async throws {
        try ensureInitialized()
        guard let store = protocolStore else {
            throw SignalCryptoError.notInitialized
        }
        try await store.resetAllKeys()
        self.sessionManager = try store.createSessionManager()
    }
}

// MARK: - Signal Network Client

/// Client for Signal Protocol server operations.
/// Handles uploading keys and fetching PreKey bundles.
actor SignalNetworkClient {

    private let baseURL: URL
    private let getAuthToken: () async throws -> String

    init(baseURL: URL, authTokenProvider: @escaping () async throws -> String) {
        self.baseURL = baseURL
        self.getAuthToken = authTokenProvider
    }

    /// Upload Signal Protocol keys to the server
    func uploadKeys(_ keys: SignalKeysUpload) async throws {
        let url = baseURL.appendingPathComponent("signal/keys")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await getAuthToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(keys)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SignalCryptoError.networkError("Failed to upload keys")
        }
    }

    /// Fetch a user's PreKey bundle
    func fetchPreKeyBundle(for userId: UUID) async throws -> SignalPreKeyBundle {
        let url = baseURL.appendingPathComponent("signal/keys/\(userId.uuidString)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(try await getAuthToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SignalCryptoError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw SignalCryptoError.preKeyBundleNotFound(userId)
            }
            throw SignalCryptoError.networkError("Failed to fetch PreKey bundle: \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(SignalPreKeyBundle.self, from: data)
    }

    /// Get the count of remaining one-time PreKeys
    func getPreKeyCount() async throws -> Int {
        let url = baseURL.appendingPathComponent("signal/keys/count")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(try await getAuthToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SignalCryptoError.networkError("Failed to get PreKey count")
        }

        let countResponse = try JSONDecoder().decode(PreKeyCountResponse.self, from: data)
        return countResponse.count
    }

    /// Upload additional one-time PreKeys
    func uploadOneTimePreKeys(_ preKeys: [OneTimePreKeyUpload]) async throws {
        let url = baseURL.appendingPathComponent("signal/keys/onetime")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await getAuthToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(preKeys)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SignalCryptoError.networkError("Failed to upload PreKeys")
        }
    }

    /// Update the signed PreKey
    func updateSignedPreKey(_ signedPreKey: SignedPreKeyUpload) async throws {
        let url = baseURL.appendingPathComponent("signal/keys/signed")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await getAuthToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(signedPreKey)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SignalCryptoError.networkError("Failed to update signed PreKey")
        }
    }
}
