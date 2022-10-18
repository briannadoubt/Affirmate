//
//  ChatSignedPreKeyStore.swift
//  Affirmate
//
//  Created by Bri on 10/15/22.
//

import Foundation
import SignalProtocol

class ChatSignedPreKeyStore: SignedPreKeyStore {
    
    var lastId: UInt32 {
        get {
            UInt32(AffirmateKeychain.chat[string: "signedPreKey.lastId"] ?? "") ?? 0
        }
        set {
            AffirmateKeychain.chat[string: "signedPreKey.lastId"] = "\(newValue)"
        }
    }
    
    private func key(for id: UInt32) -> String {
        "signedPreKey.\(id)"
    }
    
    func signedPreKey(for id: UInt32) throws -> Data {
        guard let key = AffirmateKeychain.chat[data: key(for: id)] else {
            throw SignalError(.invalidId, "No signed pre key for id \(key(for: id))")
        }
        return key
    }
    
    func store(signedPreKey: Data, for id: UInt32) throws {
        AffirmateKeychain.chat[data: key(for: id)] = signedPreKey
        lastId = id
    }
    
    func containsSignedPreKey(for id: UInt32) throws -> Bool {
        try AffirmateKeychain.chat.contains(key(for: id))
    }
    
    func removeSignedPreKey(for id: UInt32) throws {
        try AffirmateKeychain.chat.remove(key(for: id))
    }
    
    func allIds() throws -> [UInt32] {
        AffirmateKeychain.chat.allKeys().compactMap { UInt32($0) }
    }
}
