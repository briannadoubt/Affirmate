//
//  Chat.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Chat: Codable, Equatable, Identifiable, Hashable {
    
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
    
    var id: UUID
    var name: String?
    var salt: Data
    var messages: [Message]?
    var participants: [Participant]?
    
    struct Create: Object {
        var id: UUID
        var name: String?
        var salt: Data
        var participants: [Participant.Create]
        var signingKey: Data
        var encryptionKey: Data
    }
    
    struct MessageResponse: Object {
        var id: UUID
        var name: String?
    }
    
    struct ParticipantResponse: Object {
        var id: UUID
    }
}
