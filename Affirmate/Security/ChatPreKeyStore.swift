//
//  ChatPreKeyStore.swift
//  Affirmate
//
//  Created by Bri on 10/15/22.
//

import Foundation
import SignalProtocol

class ChatPreKeyStore: PreKeyStore {
    
    var lastId: UInt32 {
        get {
            UInt32(AffirmateKeychain.chat[string: "preKey.lastId"] ?? "") ?? 0
        }
        set {
            AffirmateKeychain.chat[string: "preKey.lastId"] = "\(newValue)"
        }
    }
    
    private func key(_ id: UInt32) -> String {
        "preKey.\(id)"
    }
    
    func preKey(for id: UInt32) throws -> Data {
        guard let key = AffirmateKeychain.chat[data: key(id)] else {
            throw SignalError(.storageError, "No pre key for id \(id)")
        }
        return key
    }
    
    func store(preKey: Data, for id: UInt32) throws {
        AffirmateKeychain.chat[data: key(id)] = preKey
        lastId = id
    }
    
    func containsPreKey(for id: UInt32) -> Bool {
        (try? AffirmateKeychain.chat.contains(key(id))) ?? false
    }
    
    func removePreKey(for id: UInt32) throws {
        try AffirmateKeychain.chat.remove(key(id))
    }
}
