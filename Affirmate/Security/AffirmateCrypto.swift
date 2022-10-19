//
//  AffirmateCrypto.swift
//  Affirmate
//
//  Created by Bri on 10/18/22.
//

import CryptoKit
import Foundation

enum AffirmateCryptoError: LocalizedError {
    case failedToGenerateRandomBytes
}

enum DecryptionErrors: Error {
    case authenticationError
}

actor AffirmateCrypto {
    
    typealias SealedMessage = (ephemeralPublicKeyData: Data, ciphertext: Data, signature: Data)
    
    /// Create a salt for key derivation.
    /// - Returns: A ` Data` blob containing 32 random bytes.
    func generateSalt() throws -> Data {
        var bytes = [Int8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw AffirmateCryptoError.failedToGenerateRandomBytes
        }
        return Data(bytes.map { UInt8($0) })
    }
    
    /// Generates an ephemeral key agreement key and performs key agreement to get the shared secret and derive the symmetric encryption key.
    func encrypt(
        _ data: Data,
        to theirEncryptionKey: Curve25519.KeyAgreement.PublicKey,
        signedBy ourSigningKey: Curve25519.Signing.PrivateKey
    ) throws -> SealedMessage {
        // Create ephemeral key
        // Get this from the keychain.
        // https://developer.apple.com/documentation/cryptokit/storing_cryptokit_keys_in_the_keychain
        let ephemeralKey = Curve25519.KeyAgreement.PrivateKey()
        // Extract the public key
        let ephemeralPublicKey = ephemeralKey.publicKey.rawRepresentation
        // Calculate the shared secret using the ephemeral key and their encryption key
        let sharedSecret = try ephemeralKey.sharedSecretFromKeyAgreement(with: theirEncryptionKey)
        // Calculate a symmetric key using SHA256 from the `salt` and `shared info`, into 32 bytes.
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: ephemeralPublicKey + theirEncryptionKey.rawRepresentation + ourSigningKey.publicKey.rawRepresentation,
            outputByteCount: 32
        )
        // Seal the input data using the symmetric key, and extracting the tag, the nonce, and the cyphertext into a Data blob.
        let ciphertext = try ChaChaPoly.seal(data, using: symmetricKey).combined
        // Create a signature to verify later.
        let signature = try ourSigningKey.signature(for: ciphertext + ephemeralPublicKey + theirEncryptionKey.rawRepresentation)
        return (ephemeralPublicKey, ciphertext, signature)
    }
    
    /// Generates an ephemeral key agreement key and the performs key agreement to get the shared secret and derive the symmetric encryption key.
    func decrypt(
        _ sealedMessage: SealedMessage,
        using ourKeyEncryptionKey: Curve25519.KeyAgreement.PrivateKey,
        from theirSigningKey: Curve25519.Signing.PublicKey
    ) throws -> Data {
        // Construct the encrypted data from known elements
        let data = sealedMessage.ciphertext + sealedMessage.ephemeralPublicKeyData + ourKeyEncryptionKey.publicKey.rawRepresentation
        
        // Verify the signature on the data is valid.
        guard theirSigningKey.isValidSignature(sealedMessage.signature, for: data) else {
            throw DecryptionErrors.authenticationError
        }
        
        // Extract the ephemeral key from the sealed message.
        let ephemeralKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: sealedMessage.ephemeralPublicKeyData)
        
        // Calculate the shared secret from the ephemeral key.
        let sharedSecret = try ourKeyEncryptionKey.sharedSecretFromKeyAgreement(with: ephemeralKey)
        
        // Derive the symmetric key using SHA256, and other known elements.
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: ephemeralKey.rawRepresentation +
            ourKeyEncryptionKey.publicKey.rawRepresentation +
            theirSigningKey.rawRepresentation,
            outputByteCount: 32
        )
        
        // Prepare to unseal message with a sealed box.
        let sealedBox = try ChaChaPoly.SealedBox(combined: sealedMessage.ciphertext)
        
        // return the unsealed message.
        return try ChaChaPoly.open(sealedBox, using: symmetricKey)
    }
}
