//
//  Message.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Message: IdentifiableObject {
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
    
    var id: UUID
    var text: Sealed
    var chat: Chat.MessageResponse
    var sender: Participant
    var recipient: Participant
    var created: Date?
    var updated: Date?

    struct Sealed: Codable, Hashable {
        var ephemeralPublicKeyData: Data
        var ciphertext: Data
        var signature: Data
    }
    
    struct Create: Codable {
        var sealed: Sealed
        var recipient: UUID
    }
}
