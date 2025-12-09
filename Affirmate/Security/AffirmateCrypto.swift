//
//  AffirmateCrypto.swift
//  Affirmate
//
//  Created by Bri on 10/18/22.
//

import AffirmateShared
import CryptoKit
import Foundation
import KeychainAccess

enum EncryptionError: LocalizedError {
    case failedToGenerateRandomBytes
    case unableToStorePrivateKey(_ message: String)
    case failedToGetDataRepresentation
    case keychainReadFailed(_ message: String)
    case keychainItemIsNotExpectedData
    case privateKeyNotFound
    case publicKeyNotFound
    case badUTF8Encoding
    case saltNotFound
}

enum DecryptionError: Error {
    case authenticationError
    case saltNotFound
    case privateKeyNotFound
    case senderSigningKeyDataNotFound
    case failedToBuildSealedMessage
}

protocol GenericPasswordConvertible: CustomStringConvertible {
    /// Creates a key from a raw representation.
    init<D>(rawRepresentation data: D) throws where D: ContiguousBytes
    
    /// A raw representation of the key.
    var rawRepresentation: Data { get }
}

extension Curve25519.KeyAgreement.PrivateKey: GenericPasswordConvertible {
    public var description: String {
        rawRepresentation.base64EncodedString()
    }
}

extension Curve25519.Signing.PrivateKey: GenericPasswordConvertible {
    public var description: String {
        rawRepresentation.base64EncodedString()
    }
}

/// A collection of functions for encrypting and decrypting messages.
actor AffirmateCrypto {
    
    let keychain: Keychain
    
    init(keychain: Keychain = AffirmateKeychain.chat) {
        self.keychain = keychain
    }
    
    /// Create a salt for key derivation. Stored on the server.
    /// - Returns: A ` Data` blob containing 32 random bytes.
    func generateSalt() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw EncryptionError.failedToGenerateRandomBytes
        }
        let data = Data(bytes)
        return data
    }
    
    /// Create a new signing private key (used for signing an outgoing message) and a paired public key (stored on the server).
    ///
    /// Stores the private key to the Keychain.
    ///
    /// - Parameter chatId: Used in the Keychain key calculation.
    /// - Returns: A tuple containing the `publicKey` and `privateKey` pair.
    func generateSigningKeyPair(for chatId: UUID) throws -> (publicKey: Data, privateKey: Data) {
        let privateKey = Curve25519.Signing.PrivateKey()
        try store(privateKey: privateKey, for: chatId)
        let publicKey = privateKey.publicKey
        return (publicKey: publicKey.rawRepresentation, privateKey: privateKey.rawRepresentation)
    }
    
    /// Create a new key agreement private key (used for decryption) and a paired public key (stored on the server).
    /// - Parameter chatId: Used in the Keychain key calculation.
    /// - Returns: A tuple containing the `publicKey` and `privateKey` pair.
    func generateEncryptionKeyPair(for chatId: UUID) throws -> (publicKey: Data, privateKey: Data) {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        try store(privateKey: privateKey, for: chatId)
        let publicKey = privateKey.publicKey
        return (publicKey: publicKey.rawRepresentation, privateKey: privateKey.rawRepresentation)
    }
    
    /// Calculate the key for a `Curve25519.Signing.PrivateKey` on the Keychain.
    /// - Parameter chatId: Used in the Keychain key calculation.
    /// - Returns: The key used to reference the `Curve25519.Signing.PrivateKey` on the Keychain.
    func signingKey(for chatId: UUID) -> String {
        "keys.signing." + chatId.uuidString
    }
    
    /// Calculate the key for a `Curve25519.KeyAgreement.PrivateKey` on the Keychain.
    /// - Parameter chatId: Used in the Keychain key calculation.
    /// - Returns: The key used to reference the `Curve25519.KeyAgreement.PrivateKey` on the Keychain.
    func encryptionKey(for chatId: UUID) -> String {
        "keys.encryption." + chatId.uuidString
    }
    
    /// Store a given `Curve25519.Signing.PrivateKey` to the Keychain.
    /// - Parameters:
    ///   - privateKey: The `Curve25519.Signing.PrivateKey` to be stored.
    ///   - chatId: The chatId that references the relevant Chat. This is used for the key on the Keychain.
    func store(privateKey: Curve25519.Signing.PrivateKey, for chatId: UUID) throws {
        keychain[data: signingKey(for: chatId)] = privateKey.rawRepresentation
    }
    
    /// Store a given `Curve25519.KeyAgreement.PrivateKey` to the Keychain.
    /// - Parameters:
    ///   - privateKey: The `Curve25519.KeyAgreement.PrivateKey` to be stored.
    ///   - chatId: The chatId that references the relevant Chat. This is used for the key on the Keychain.
    func store(privateKey: Curve25519.KeyAgreement.PrivateKey, for chatId: UUID) throws {
        keychain[data: encryptionKey(for: chatId)] = privateKey.rawRepresentation
    }
    
    /// Fetch a stored `KeyAgreement` private key from the Keychain, using the `chatId` as reference.
    /// - Parameter chatId: The chatId that references the relevant Chat. This is used for the key on the Keychain.
    /// - Returns: The `Curve25519.KeyAgreement.PrivateKey` if the key exists on the Keychain, `nil` otherwise.
    func getPrivateEncryptionKey(for chatId: UUID) throws -> Curve25519.KeyAgreement.PrivateKey? {
        guard let data = try keychain.getData(encryptionKey(for: chatId)) else {
            return nil
        }
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }
    
    /// Fetch a stored `Signing` private key from the Keychain, using the `chatId` as reference.
    /// - Parameter chatId: The chatId that references the relevant Chat. This is used for the key on the Keychain.
    /// - Returns: The `Curve25519.KeyAgreement.PrivateKey` if the key exists on the Keychain, `nil` otherwise.
    func getPrivateSigningKey(for chatId: UUID) throws -> Curve25519.Signing.PrivateKey? {
        guard let data = try keychain.getData(signingKey(for: chatId)) else {
            return nil
        }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }
    
    /// Generates an ephemeral key agreement and performs calculations to retrieve the shared secret; and derive the symmetric encryption key.
    ///
    /// This function completes the following steps:
    ///  1. Creates an ephemeral key for forward secrecy.
    ///  2. Extracts the ephemeral public key from the new key.
    ///  3. Calculates the shared secret using the ephemeral key and the other person's public key agreement key.
    ///  4. Calculates a symmetric key using SHA256 from the salt, the ephemeral key, the other user's encryption key, and our signing key, into 32 bytes.
    ///  5. Seals the input data using the symmetric key, and extracts the tag, the nonce, and the cyphertext into a Data blob.
    ///  6. Creates a signature to verify later.
    ///  7. Creates the sealed message object with calculated data and returns it.
    ///
    /// - Parameters:
    ///   - data: The data to encrypt.
    ///   - salt: The salt, obtained from the server.
    ///   - encryptionKey: The public encryption key.
    ///   - signingKey: The private signing key.
    ///
    /// - Returns: A sealed message to be sent to the other user.
    func encrypt(_ data: Data, salt: Data, to encryptionKey: Curve25519.KeyAgreement.PublicKey, signedBy signingKey: Curve25519.Signing.PrivateKey) throws -> MessageSealed {
        // 1. Create ephemeral key for forward secrecy.
        let ephemeralKey = Curve25519.KeyAgreement.PrivateKey()
        // 2. Extract the ephemeral public key.
        let ephemeralPublicKey = ephemeralKey.publicKey.rawRepresentation
        // 3. Calculate the shared secret using the ephemeral key and their encryption key.
        let sharedSecret = try ephemeralKey.sharedSecretFromKeyAgreement(with: encryptionKey)
        // 4. Calculate a symmetric key using SHA256 from the `salt` and `shared info`, into 32 bytes.
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: ephemeralPublicKey + encryptionKey.rawRepresentation + signingKey.publicKey.rawRepresentation,
            outputByteCount: 32
        )
        // 5. Seal the input data using the symmetric key, and extracting the tag, the nonce, and the cyphertext into a Data blob.
        let ciphertext = try ChaChaPoly.seal(data, using: symmetricKey).combined
        // 6. Create a signature to verify later.
        let signature = try signingKey.signature(for: ciphertext + ephemeralPublicKey + encryptionKey.rawRepresentation)
        // 7. Return the sealed message
        return MessageSealed(
            ephemeralPublicKeyData: ephemeralPublicKey,
            ciphertext: ciphertext,
            signature: signature
        )
    }
    
    /// Calculates the shared secret and symmetric key, then unseals the message.
    ///
    /// This function completes the following steps:
    /// 1. Constructs the encrypted data from known elements.
    /// 2. Verifies the signature on the data is valid.
    /// 3. Extracts the ephemeral key from the sealed message.
    /// 4. Calculates the shared secret from the ephemeral key.
    /// 5. Calculates a symmetric key using SHA256 from the salt, the ephemeral key, the other user's encryption key, and our signing key, into 32 bytes.
    /// 6. Creates a sealed box with the sealed message, which prepares for unsealing the message.
    /// 7. Opens the sealed box and unseals the message.
    ///
    /// - Parameters:
    ///   - sealedMessage: The data to decrypt.
    ///   - salt: The salt, obtained from the server.
    ///   - encryptionKey: The private encryption key.
    ///   - signingKey:The public signing key.
    ///
    /// - Returns: A decrypted message to be decoded and utilized.
    func decrypt(_ sealedMessage: MessageSealed, salt: Data, using encryptionKey: Curve25519.KeyAgreement.PrivateKey, from signingKey: Curve25519.Signing.PublicKey) throws -> Data {
        // 1. Construct the encrypted data from known elements
        let data = sealedMessage.ciphertext + sealedMessage.ephemeralPublicKeyData + encryptionKey.publicKey.rawRepresentation
        // 2. Verify the signature on the data is valid.
        guard signingKey.isValidSignature(sealedMessage.signature, for: data) else {
            throw DecryptionError.authenticationError
        }
        // 3. Extract the ephemeral key from the sealed message.
        let ephemeralKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: sealedMessage.ephemeralPublicKeyData)
        // 4. Calculate the shared secret from the ephemeral key.
        let sharedSecret = try encryptionKey.sharedSecretFromKeyAgreement(with: ephemeralKey)
        // 5. Calculate a symmetric key using SHA256 from the `salt` and `shared info`, into 32 bytes.
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: ephemeralKey.rawRepresentation +
            encryptionKey.publicKey.rawRepresentation +
            signingKey.rawRepresentation,
            outputByteCount: 32
        )
        // 6. Prepare to unseal message with a sealed box.
        let sealedBox = try ChaChaPoly.SealedBox(combined: sealedMessage.ciphertext)
        // 7. Unseal and return the message.
        return try ChaChaPoly.open(sealedBox, using: symmetricKey)
    }
}
