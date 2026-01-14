//
//  X3DH.swift
//  Affirmate
//
//  Extended Triple Diffie-Hellman key agreement protocol.
//  Reference: https://signal.org/docs/specifications/x3dh/
//

import CryptoKit
import Foundation

// MARK: - X3DH Key Agreement

/// Extended Triple Diffie-Hellman (X3DH) key agreement protocol.
/// Used to establish a shared secret between two parties for initial session setup.
actor X3DH {

    /// KDF info for deriving the shared secret
    private static let kdfInfo = Data("X3DH_SharedSecret".utf8)

    // MARK: - Initiator (Alice) Side

    /// Perform X3DH key agreement as the initiator.
    /// Alice uses Bob's PreKey bundle to establish a shared secret.
    ///
    /// - Parameters:
    ///   - identityKeyPair: Alice's long-term identity key pair
    ///   - preKeyBundle: Bob's PreKey bundle from the server
    /// - Returns: The shared secret key material and ephemeral key used
    func initiateKeyAgreement(
        identityKeyPair: IdentityKeyPair,
        preKeyBundle: PreKeyBundle
    ) throws -> X3DHInitiatorResult {
        // 1. Verify the signed PreKey signature
        guard try preKeyBundle.verifySignature() else {
            throw SignalProtocolError.signatureVerificationFailed
        }

        // 2. Generate ephemeral key pair
        let ephemeralKeyPair = KeyAgreementKeyPair()

        // 3. Perform the DH calculations
        // DH1 = DH(IK_A, SPK_B)
        let dh1 = try identityKeyPair.agreementKeyPair.sharedSecret(with: preKeyBundle.signedPreKey)

        // DH2 = DH(EK_A, IK_B)
        let dh2 = try ephemeralKeyPair.sharedSecret(with: preKeyBundle.identityAgreementKey)

        // DH3 = DH(EK_A, SPK_B)
        let dh3 = try ephemeralKeyPair.sharedSecret(with: preKeyBundle.signedPreKey)

        // DH4 = DH(EK_A, OPK_B) if one-time PreKey is present
        var dh4: SharedSecret?
        if let oneTimePreKey = preKeyBundle.oneTimePreKey {
            dh4 = try ephemeralKeyPair.sharedSecret(with: oneTimePreKey)
        }

        // 5. Concatenate all DH outputs
        var dhConcat = dh1.withUnsafeBytes { Data($0) }
        dhConcat.append(dh2.withUnsafeBytes { Data($0) })
        dhConcat.append(dh3.withUnsafeBytes { Data($0) })
        if let dh4 = dh4 {
            dhConcat.append(dh4.withUnsafeBytes { Data($0) })
        }

        // 6. Derive the shared secret using HKDF
        let sharedSecret = deriveSharedSecret(from: dhConcat)

        return X3DHInitiatorResult(
            sharedSecret: sharedSecret,
            ephemeralKeyPair: ephemeralKeyPair,
            usedOneTimePreKeyId: preKeyBundle.oneTimePreKeyId,
            usedSignedPreKeyId: preKeyBundle.signedPreKeyId
        )
    }

    // MARK: - Responder (Bob) Side

    /// Perform X3DH key agreement as the responder.
    /// Bob uses his stored keys and Alice's initial message to derive the shared secret.
    ///
    /// - Parameters:
    ///   - identityKeyPair: Bob's long-term identity key pair
    ///   - signedPreKey: Bob's signed PreKey that was used
    ///   - oneTimePreKey: Bob's one-time PreKey that was used (if any)
    ///   - theirIdentityKey: Alice's public identity key
    ///   - theirEphemeralKey: Alice's ephemeral public key
    /// - Returns: The derived shared secret
    func respondToKeyAgreement(
        identityKeyPair: IdentityKeyPair,
        signedPreKey: SignedPreKey,
        oneTimePreKey: OneTimePreKey?,
        theirIdentityAgreementKey: Data,
        theirEphemeralKey: Data
    ) throws -> Data {
        // 1. Perform the DH calculations (mirroring Alice's calculations)
        // DH1 = DH(SPK_B, IK_A)
        let dh1 = try signedPreKey.keyPair.sharedSecret(with: theirIdentityAgreementKey)

        // DH2 = DH(IK_B, EK_A)
        let dh2 = try identityKeyPair.agreementKeyPair.sharedSecret(with: theirEphemeralKey)

        // DH3 = DH(SPK_B, EK_A)
        let dh3 = try signedPreKey.keyPair.sharedSecret(with: theirEphemeralKey)

        // DH4 = DH(OPK_B, EK_A) if one-time PreKey was used
        var dh4: SharedSecret?
        if let otpk = oneTimePreKey {
            dh4 = try otpk.keyPair.sharedSecret(with: theirEphemeralKey)
        }

        // 4. Concatenate all DH outputs
        var dhConcat = dh1.withUnsafeBytes { Data($0) }
        dhConcat.append(dh2.withUnsafeBytes { Data($0) })
        dhConcat.append(dh3.withUnsafeBytes { Data($0) })
        if let dh4 = dh4 {
            dhConcat.append(dh4.withUnsafeBytes { Data($0) })
        }

        // 5. Derive the shared secret using HKDF
        return deriveSharedSecret(from: dhConcat)
    }

    // MARK: - Helper Functions

    /// Derive the final shared secret using HKDF
    private func deriveSharedSecret(from dhConcat: Data) -> Data {
        // Prepend F = 0xFF * 32 as per X3DH spec for cryptographic domain separation
        var input = Data(repeating: 0xFF, count: 32)
        input.append(dhConcat)

        let inputKey = SymmetricKey(data: input)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: Data(), // Empty salt as per spec
            info: Self.kdfInfo,
            outputByteCount: 32
        )

        var result = Data()
        derivedKey.withUnsafeBytes { result.append(contentsOf: $0) }
        return result
    }
}

// MARK: - X3DH Results

/// Result of X3DH key agreement from the initiator's side
struct X3DHInitiatorResult {
    /// The derived shared secret
    let sharedSecret: Data
    /// The ephemeral key pair used
    let ephemeralKeyPair: KeyAgreementKeyPair
    /// ID of the one-time PreKey used (if any)
    let usedOneTimePreKeyId: UInt32?
    /// ID of the signed PreKey used
    let usedSignedPreKeyId: UInt32
}

// MARK: - PreKey Manager

/// Manages PreKey generation and storage
actor PreKeyManager {

    private var signedPreKey: SignedPreKey?
    private var oneTimePreKeys: [UInt32: OneTimePreKey] = [:]
    private var nextPreKeyId: UInt32 = 1
    private var nextSignedPreKeyId: UInt32 = 1

    /// Recommended number of one-time PreKeys to maintain
    private let recommendedPreKeyCount: Int = 100

    /// Generate a new signed PreKey
    func generateSignedPreKey(identityKey: IdentityKeyPair) throws -> SignedPreKey {
        let id = nextSignedPreKeyId
        nextSignedPreKeyId += 1
        let spk = try SignedPreKey(id: id, identityKey: identityKey)
        self.signedPreKey = spk
        return spk
    }

    /// Generate a batch of one-time PreKeys
    func generateOneTimePreKeys(count: Int) -> [OneTimePreKey] {
        var keys: [OneTimePreKey] = []
        for _ in 0..<count {
            let id = nextPreKeyId
            nextPreKeyId += 1
            let key = OneTimePreKey(id: id)
            oneTimePreKeys[id] = key
            keys.append(key)
        }
        return keys
    }

    /// Get the current signed PreKey
    func getSignedPreKey() -> SignedPreKey? {
        signedPreKey
    }

    /// Get a one-time PreKey by ID and remove it (each can only be used once)
    func consumeOneTimePreKey(id: UInt32) -> OneTimePreKey? {
        oneTimePreKeys.removeValue(forKey: id)
    }

    /// Get the current one-time PreKey count
    func getOneTimePreKeyCount() -> Int {
        oneTimePreKeys.count
    }

    /// Check if more PreKeys need to be generated
    func needsMorePreKeys() -> Bool {
        oneTimePreKeys.count < recommendedPreKeyCount / 2
    }

    /// Create a PreKey bundle for publishing to the server
    func createPreKeyBundle(identityKey: IdentityKeyPair) throws -> PreKeyBundle {
        guard let spk = signedPreKey else {
            throw SignalProtocolError.invalidPreKeyBundle
        }

        // Get one one-time PreKey if available (don't consume it yet)
        let otpk = oneTimePreKeys.values.first

        return PreKeyBundle(
            identityKey: identityKey.publicKey,
            identityAgreementKey: identityKey.agreementKeyPair.publicKey,
            signedPreKeyId: spk.id,
            signedPreKey: spk.keyPair.publicKey,
            signedPreKeySignature: spk.signature,
            oneTimePreKeyId: otpk?.id,
            oneTimePreKey: otpk?.keyPair.publicKey
        )
    }

    /// Set the signed PreKey (when loading from storage)
    func setSignedPreKey(_ spk: SignedPreKey) {
        self.signedPreKey = spk
    }

    /// Set one-time PreKeys (when loading from storage)
    func setOneTimePreKeys(_ keys: [OneTimePreKey]) {
        for key in keys {
            oneTimePreKeys[key.id] = key
        }
    }

    /// Set the next PreKey ID counter
    func setNextPreKeyId(_ id: UInt32) {
        self.nextPreKeyId = id
    }

    /// Set the next signed PreKey ID counter
    func setNextSignedPreKeyId(_ id: UInt32) {
        self.nextSignedPreKeyId = id
    }

    /// Get all one-time PreKeys (for storage)
    func getAllOneTimePreKeys() -> [OneTimePreKey] {
        Array(oneTimePreKeys.values)
    }
}
