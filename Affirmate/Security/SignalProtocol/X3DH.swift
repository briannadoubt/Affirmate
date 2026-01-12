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

    /// Protocol information string used in key derivation
    private static let protocolInfo = Data("Signal_X3DH".utf8)

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

        // 3. Build identity key for DH (convert signing key to agreement key)
        // In Signal, identity keys can be used for both signing and DH
        // We use X25519 for DH, so we need to convert or use separate keys
        // For simplicity, we generate a separate identity agreement key
        let identityAgreementKey = try deriveAgreementKey(from: identityKeyPair)

        // 4. Perform the DH calculations
        // DH1 = DH(IK_A, SPK_B)
        let dh1 = try identityAgreementKey.sharedSecret(with: preKeyBundle.signedPreKey)

        // DH2 = DH(EK_A, IK_B)
        // Need Bob's identity key as agreement key
        let bobIdentityAgreementKey = try convertSigningKeyToAgreementKey(preKeyBundle.identityKey)
        let dh2 = try ephemeralKeyPair.sharedSecret(with: bobIdentityAgreementKey)

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
        theirIdentityKey: Data,
        theirEphemeralKey: Data
    ) throws -> Data {
        // 1. Build our identity agreement key
        let identityAgreementKey = try deriveAgreementKey(from: identityKeyPair)

        // 2. Convert their identity key to agreement key
        let theirIdentityAgreementKey = try convertSigningKeyToAgreementKey(theirIdentityKey)

        // 3. Perform the DH calculations (mirroring Alice's calculations)
        // DH1 = DH(SPK_B, IK_A)
        let dh1 = try signedPreKey.keyPair.sharedSecret(with: theirIdentityAgreementKey)

        // DH2 = DH(IK_B, EK_A)
        let dh2 = try identityAgreementKey.sharedSecret(with: theirEphemeralKey)

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

    /// Derive an agreement key from an identity key pair.
    /// We use a deterministic derivation to get a Curve25519 key agreement key.
    private func deriveAgreementKey(from identityKey: IdentityKeyPair) throws -> KeyAgreementKeyPair {
        // Use HKDF to derive key material for a new agreement key
        let inputKey = SymmetricKey(data: identityKey.privateKey)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: Data("IdentityToAgreement".utf8),
            info: Self.protocolInfo,
            outputByteCount: 32
        )

        var keyData = Data()
        derivedKey.withUnsafeBytes { keyData.append(contentsOf: $0) }

        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData)
        return KeyAgreementKeyPair(
            privateKey: privateKey.rawRepresentation,
            publicKey: privateKey.publicKey.rawRepresentation
        )
    }

    /// Convert a signing public key to an agreement public key.
    /// Uses the raw representation directly since Curve25519 points are the same.
    private func convertSigningKeyToAgreementKey(_ signingKeyData: Data) throws -> Data {
        // For Curve25519, the point representation is the same
        // We just need to ensure it's valid as an agreement key
        let key = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: signingKeyData)
        return key.rawRepresentation
    }

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
