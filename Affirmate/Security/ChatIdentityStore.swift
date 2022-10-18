//
//  ChatIdentityStore.swift
//  Affirmate
//
//  Created by Bri on 10/15/22.
//

import Foundation
import SignalProtocol

class ChatIdentityStore: IdentityKeyStore {
    
    typealias Address = AffirmateAddress
    
    private func key(_ address: AffirmateAddress) -> String {
        "identity.\(address.description)"
    }
    
    private var identityKey: Data? {
        get {
            AffirmateKeychain.chat[data: Constants.KeyChain.Chat.identity]
        }
        set {
            AffirmateKeychain.chat[data: Constants.KeyChain.Chat.identity] = newValue
        }
    }
    
    init(with keyPair: Data) {
        self.identityKey = keyPair
    }
    
    init() { }
    
    func getIdentityKeyData() throws -> Data {
        guard let identityKey = identityKey else {
            let newIdentityKey = try SignalCrypto.generateIdentityKeyPair()
            self.identityKey = newIdentityKey
            return newIdentityKey
        }
        return identityKey
    }
    
    func identity(for address: AffirmateAddress) throws -> Data? {
        AffirmateKeychain.chat[data: key(address)]
    }
    
    /// Store a remote client's identity key as trusted to the keychain. If the identity passed in is `nil` then the identity will be removed from the keychain.
    /// - Parameters:
    ///   - identity: The identity key data (may be nil, if the key should be removed)
    ///   - address: The address of the remote client
    func store(identity: Data?, for address: AffirmateAddress) throws {
        AffirmateKeychain.chat[data: key(address)] = identity
    }
}
