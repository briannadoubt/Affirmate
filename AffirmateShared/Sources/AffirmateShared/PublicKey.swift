//
//  PublicKey.swift
//  AffirmateShared
//
//  Created by Bri on 11/21/22.
//

import Foundation

/// Create a new public key.
public struct PublicKeyCreate: Equatable, Hashable, Codable {
    /// The public signing key data.
    public var signingKey: Data
    /// The public encryption key data.
    public var encryptionKey: Data
    
    /// Create a new public key.
    /// - Parameters:
    ///   - signingKey: The public signing key data.
    ///   - encryptionKey: The public encryption key data.
    init(signingKey: Data, encryptionKey: Data) {
        self.signingKey = signingKey
        self.encryptionKey = encryptionKey
    }
}
