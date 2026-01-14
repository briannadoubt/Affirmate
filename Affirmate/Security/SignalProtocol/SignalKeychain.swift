//
//  SignalKeychain.swift
//  Affirmate
//
//  Secure storage for Signal Protocol keys using iOS Keychain.
//

import Foundation
import KeychainAccess

// MARK: - Signal Keychain Keys

private enum SignalKeychainKeys {
    static let identityKeyPair = "signal.identity.keypair"
    static let signedPreKey = "signal.signed.prekey"
    static let oneTimePreKeysPrefix = "signal.onetime.prekey."
    static let nextPreKeyId = "signal.prekey.next.id"
    static let nextSignedPreKeyId = "signal.signed.prekey.next.id"
    static let registrationId = "signal.registration.id"
}

// MARK: - Signal Keychain Manager

/// Manages secure storage of Signal Protocol keys in the iOS Keychain.
actor SignalKeychainManager {

    private let keychain: Keychain

    init(keychain: Keychain = AffirmateKeychain.chat) {
        self.keychain = keychain
    }

    // MARK: - Identity Key

    /// Store the identity key pair
    func storeIdentityKeyPair(_ keyPair: IdentityKeyPair) throws {
        let data = try JSONEncoder().encode(keyPair)
        keychain[data: SignalKeychainKeys.identityKeyPair] = data
    }

    /// Load the identity key pair
    func loadIdentityKeyPair() throws -> IdentityKeyPair? {
        guard let data = try keychain.getData(SignalKeychainKeys.identityKeyPair) else {
            return nil
        }
        return try JSONDecoder().decode(IdentityKeyPair.self, from: data)
    }

    /// Get or create the identity key pair
    func getOrCreateIdentityKeyPair() throws -> IdentityKeyPair {
        if let existing = try loadIdentityKeyPair() {
            return existing
        }
        let keyPair = IdentityKeyPair()
        try storeIdentityKeyPair(keyPair)
        return keyPair
    }

    // MARK: - Signed PreKey

    /// Store the current signed PreKey
    func storeSignedPreKey(_ preKey: SignedPreKey) throws {
        let data = try JSONEncoder().encode(preKey)
        keychain[data: SignalKeychainKeys.signedPreKey] = data
    }

    /// Load the current signed PreKey
    func loadSignedPreKey() throws -> SignedPreKey? {
        guard let data = try keychain.getData(SignalKeychainKeys.signedPreKey) else {
            return nil
        }
        return try JSONDecoder().decode(SignedPreKey.self, from: data)
    }

    // MARK: - One-Time PreKeys

    /// Store a one-time PreKey
    func storeOneTimePreKey(_ preKey: OneTimePreKey) throws {
        let key = SignalKeychainKeys.oneTimePreKeysPrefix + String(preKey.id)
        let data = try JSONEncoder().encode(preKey)
        keychain[data: key] = data
    }

    /// Load a one-time PreKey by ID
    func loadOneTimePreKey(id: UInt32) throws -> OneTimePreKey? {
        let key = SignalKeychainKeys.oneTimePreKeysPrefix + String(id)
        guard let data = try keychain.getData(key) else {
            return nil
        }
        return try JSONDecoder().decode(OneTimePreKey.self, from: data)
    }

    /// Delete a one-time PreKey by ID (after it's been used)
    func deleteOneTimePreKey(id: UInt32) throws {
        let key = SignalKeychainKeys.oneTimePreKeysPrefix + String(id)
        try keychain.remove(key)
    }

    /// Load all one-time PreKeys
    func loadAllOneTimePreKeys() throws -> [OneTimePreKey] {
        var preKeys: [OneTimePreKey] = []
        let allItems = keychain.allItems()

        for item in allItems {
            guard let key = item["key"] as? String,
                  key.hasPrefix(SignalKeychainKeys.oneTimePreKeysPrefix),
                  let data = try keychain.getData(key) else {
                continue
            }
            if let preKey = try? JSONDecoder().decode(OneTimePreKey.self, from: data) {
                preKeys.append(preKey)
            }
        }

        return preKeys
    }

    /// Store multiple one-time PreKeys
    func storeOneTimePreKeys(_ preKeys: [OneTimePreKey]) throws {
        for preKey in preKeys {
            try storeOneTimePreKey(preKey)
        }
    }

    // MARK: - PreKey ID Counters

    /// Store the next PreKey ID
    func storeNextPreKeyId(_ id: UInt32) throws {
        keychain[SignalKeychainKeys.nextPreKeyId] = String(id)
    }

    /// Load the next PreKey ID
    func loadNextPreKeyId() throws -> UInt32 {
        guard let string = try keychain.getString(SignalKeychainKeys.nextPreKeyId),
              let id = UInt32(string) else {
            return 1
        }
        return id
    }

    /// Store the next signed PreKey ID
    func storeNextSignedPreKeyId(_ id: UInt32) throws {
        keychain[SignalKeychainKeys.nextSignedPreKeyId] = String(id)
    }

    /// Load the next signed PreKey ID
    func loadNextSignedPreKeyId() throws -> UInt32 {
        guard let string = try keychain.getString(SignalKeychainKeys.nextSignedPreKeyId),
              let id = UInt32(string) else {
            return 1
        }
        return id
    }

    // MARK: - Registration ID

    /// Store the registration ID
    func storeRegistrationId(_ id: UInt32) throws {
        keychain[SignalKeychainKeys.registrationId] = String(id)
    }

    /// Load the registration ID
    func loadRegistrationId() throws -> UInt32? {
        guard let string = try keychain.getString(SignalKeychainKeys.registrationId),
              let id = UInt32(string) else {
            return nil
        }
        return id
    }

    /// Get or create the registration ID
    func getOrCreateRegistrationId() throws -> UInt32 {
        if let existing = try loadRegistrationId() {
            return existing
        }
        // Generate random registration ID (avoiding 0)
        let id = UInt32.random(in: 1...UInt32.max)
        try storeRegistrationId(id)
        return id
    }

    // MARK: - Cleanup

    /// Delete all Signal Protocol keys (used when resetting the account)
    func deleteAllKeys() throws {
        // Delete identity key
        try keychain.remove(SignalKeychainKeys.identityKeyPair)

        // Delete signed PreKey
        try keychain.remove(SignalKeychainKeys.signedPreKey)

        // Delete all one-time PreKeys
        let allItems = keychain.allItems()
        for item in allItems {
            if let key = item["key"] as? String,
               key.hasPrefix(SignalKeychainKeys.oneTimePreKeysPrefix) {
                try keychain.remove(key)
            }
        }

        // Delete counters
        try keychain.remove(SignalKeychainKeys.nextPreKeyId)
        try keychain.remove(SignalKeychainKeys.nextSignedPreKeyId)
        try keychain.remove(SignalKeychainKeys.registrationId)
    }
}

// MARK: - Signal Protocol Store

/// Coordinates Signal Protocol key management and persistence.
/// This is the main entry point for setting up and managing Signal Protocol keys.
actor SignalProtocolStore {

    private let keychainManager: SignalKeychainManager
    private let preKeyManager: PreKeyManager
    private var identityKeyPair: IdentityKeyPair?
    private var registrationId: UInt32?

    /// Number of one-time PreKeys to generate initially
    private let initialPreKeyCount = 100
    /// Minimum number of PreKeys before regenerating more
    private let minPreKeyThreshold = 25

    init(keychain: Keychain = AffirmateKeychain.chat) {
        self.keychainManager = SignalKeychainManager(keychain: keychain)
        self.preKeyManager = PreKeyManager()
    }

    // MARK: - Initialization

    /// Initialize the Signal Protocol store.
    /// Loads existing keys or generates new ones.
    func initialize() async throws {
        // Load or create identity key
        identityKeyPair = try await keychainManager.getOrCreateIdentityKeyPair()

        // Load or create registration ID
        registrationId = try await keychainManager.getOrCreateRegistrationId()

        // Load existing PreKeys
        try await loadPreKeys()

        // Ensure we have enough PreKeys
        try await ensurePreKeys()
    }

    /// Load PreKeys from keychain
    private func loadPreKeys() async throws {
        // Load signed PreKey
        if let signedPreKey = try await keychainManager.loadSignedPreKey() {
            await preKeyManager.setSignedPreKey(signedPreKey)
        }

        // Load one-time PreKeys
        let oneTimePreKeys = try await keychainManager.loadAllOneTimePreKeys()
        await preKeyManager.setOneTimePreKeys(oneTimePreKeys)

        // Load counters
        let nextPreKeyId = try await keychainManager.loadNextPreKeyId()
        let nextSignedPreKeyId = try await keychainManager.loadNextSignedPreKeyId()
        await preKeyManager.setNextPreKeyId(nextPreKeyId)
        await preKeyManager.setNextSignedPreKeyId(nextSignedPreKeyId)
    }

    /// Ensure we have enough PreKeys
    private func ensurePreKeys() async throws {
        guard let identityKey = identityKeyPair else {
            throw SignalProtocolError.invalidKeyData
        }

        // Generate signed PreKey if needed
        if await preKeyManager.getSignedPreKey() == nil {
            let signedPreKey = try await preKeyManager.generateSignedPreKey(identityKey: identityKey)
            try await keychainManager.storeSignedPreKey(signedPreKey)
        }

        // Generate one-time PreKeys if needed
        if await preKeyManager.needsMorePreKeys() {
            let count = initialPreKeyCount - await preKeyManager.getOneTimePreKeyCount()
            if count > 0 {
                let newPreKeys = await preKeyManager.generateOneTimePreKeys(count: count)
                try await keychainManager.storeOneTimePreKeys(newPreKeys)
            }
        }
    }

    // MARK: - Public Interface

    /// Get the identity key pair
    func getIdentityKeyPair() throws -> IdentityKeyPair {
        guard let keyPair = identityKeyPair else {
            throw SignalProtocolError.invalidKeyData
        }
        return keyPair
    }

    /// Get the registration ID
    func getRegistrationId() throws -> UInt32 {
        guard let id = registrationId else {
            throw SignalProtocolError.invalidKeyData
        }
        return id
    }

    /// Get the PreKey manager
    func getPreKeyManager() -> PreKeyManager {
        preKeyManager
    }

    /// Create a PreKey bundle for publishing to the server
    func createPreKeyBundle() async throws -> PreKeyBundle {
        guard let identityKey = identityKeyPair else {
            throw SignalProtocolError.invalidKeyData
        }
        return try await preKeyManager.createPreKeyBundle(identityKey: identityKey)
    }

    /// Create a session manager
    func createSessionManager() throws -> SignalSessionManager {
        guard let identityKey = identityKeyPair else {
            throw SignalProtocolError.invalidKeyData
        }
        return SignalSessionManager(
            identityKeyPair: identityKey,
            preKeyManager: preKeyManager
        )
    }

    /// Consume a one-time PreKey (after receiving a message that used it)
    func consumeOneTimePreKey(id: UInt32) async throws {
        _ = await preKeyManager.consumeOneTimePreKey(id: id)
        try await keychainManager.deleteOneTimePreKey(id: id)

        // Check if we need more PreKeys
        if await preKeyManager.needsMorePreKeys() {
            try await ensurePreKeys()
        }
    }

    /// Rotate the signed PreKey
    func rotateSignedPreKey() async throws {
        guard let identityKey = identityKeyPair else {
            throw SignalProtocolError.invalidKeyData
        }

        let newSignedPreKey = try await preKeyManager.generateSignedPreKey(identityKey: identityKey)
        try await keychainManager.storeSignedPreKey(newSignedPreKey)
    }

    /// Reset all Signal Protocol keys (careful - this will invalidate all sessions!)
    func resetAllKeys() async throws {
        try await keychainManager.deleteAllKeys()
        identityKeyPair = nil
        registrationId = nil
        try await initialize()
    }

    /// Get the public keys needed for the server
    func getPublicKeys() async throws -> SignalPublicKeys {
        guard let identityKey = identityKeyPair,
              let regId = registrationId else {
            throw SignalProtocolError.invalidKeyData
        }

        let bundle = try await createPreKeyBundle()

        return SignalPublicKeys(
            registrationId: regId,
            identityKey: identityKey.publicKey,
            identityAgreementKey: identityKey.agreementKeyPair.publicKey,
            signedPreKeyId: bundle.signedPreKeyId,
            signedPreKey: bundle.signedPreKey,
            signedPreKeySignature: bundle.signedPreKeySignature,
            oneTimePreKeys: await preKeyManager.getAllOneTimePreKeys().map {
                OneTimePreKeyPublic(id: $0.id, key: $0.keyPair.publicKey)
            }
        )
    }
}

// MARK: - Public Key Structures

/// Public keys to upload to the server
struct SignalPublicKeys: Codable {
    let registrationId: UInt32
    let identityKey: Data
    let identityAgreementKey: Data
    let signedPreKeyId: UInt32
    let signedPreKey: Data
    let signedPreKeySignature: Data
    let oneTimePreKeys: [OneTimePreKeyPublic]
}

/// Public one-time PreKey for server storage
struct OneTimePreKeyPublic: Codable {
    let id: UInt32
    let key: Data
}
