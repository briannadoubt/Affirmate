//
//  ChatSessionStore.swift
//  Affirmate
//
//  Created by Bri on 10/15/22.
//

import Foundation
import SignalProtocol

class ChatSessionStore: SessionStore {
    
    typealias Address = AffirmateAddress
    
    private func key(_ address: AffirmateAddress) -> String {
        "session.\(address.description)"
    }
    
    func loadSession(for address: AffirmateAddress) throws -> Data? {
        AffirmateKeychain.chat[data: key(address)]
    }
    
    func store(session: Data, for address: AffirmateAddress) throws {
        AffirmateKeychain.chat[data: key(address)] = session
    }
    
    func containsSession(for address: AffirmateAddress) -> Bool {
        (try? AffirmateKeychain.chat.contains(key(address))) ?? false
    }
    
    func deleteSession(for address: AffirmateAddress) throws {
        try AffirmateKeychain.chat.remove(key(address))
    }
}
