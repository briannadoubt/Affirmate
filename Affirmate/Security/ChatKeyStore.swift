//
//  ChatKeyStore.swift
//  Affirmate
//
//  Created by Bri on 10/15/22.
//

import Foundation
import SignalProtocol

class ChatKeyStore: GroupKeyStore {
    
    /// The identifier to distinguish between different devices/users.
    typealias Address = AffirmateAddress
    
    /// The identifier to distinguish between different groups and devices/users.
    typealias GroupAddress = AffirmateSenderKeyName
    
    /// The type implementing the identity key store.
    typealias IdentityKeyStoreType = ChatIdentityStore
    
    /// The type implementing the sender key store.
    typealias SenderKeyStoreType = ChatSenderKeyStore
    
    /// The type implementing the session store.
    typealias SessionStoreType = ChatSessionStore
    
    /// The store for the identity keys.
    var identityKeyStore: ChatIdentityStore
    
    /// The store for the pre keys.
    let preKeyStore: PreKeyStore = ChatPreKeyStore()
    
    /// The store for the signed pre keys.
    let signedPreKeyStore: SignedPreKeyStore = ChatSignedPreKeyStore()
    
    /// The store for the sender keys.
    let senderKeyStore = ChatSenderKeyStore()
    
    /// The store for the sessions.
    let sessionStore = ChatSessionStore()
    
    init(with keyPair: Data) {
        self.identityKeyStore = ChatIdentityStore(with: keyPair)
    }
    
    init() {
        self.identityKeyStore = ChatIdentityStore()
    }
}
