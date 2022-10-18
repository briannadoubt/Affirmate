//
//  ChatSenderKeyStore.swift
//  Affirmate
//
//  Created by Bri on 10/17/22.
//

import Foundation
import SignalProtocol

class ChatSenderKeyStore: SenderKeyStore {
    
    /// The type that distinguishes different groups and devices/users
    typealias Address = AffirmateSenderKeyName
    
    private func key(for address: AffirmateSenderKeyName) -> String {
        return "sender.\(address.description)"
    }
    
    /// Returns a copy of the sender key record corresponding to the address tuple.
    /// - Parameter address: The group address of the remote client
    /// - Returns: The Sender Key, if it exists, or nil
    func senderKey(for address: AffirmateSenderKeyName) -> Data? {
        AffirmateKeychain.chat[data: key(for: address)]
    }
    
    /// Stores the sender key record.
    /// - Parameters:
    ///   - senderKey: The key to store
    ///   - address: The group address of the remote client
    func store(senderKey: Data, for address: AffirmateSenderKeyName) throws {
        AffirmateKeychain.chat[data: key(for: address)] = senderKey
    }
}
