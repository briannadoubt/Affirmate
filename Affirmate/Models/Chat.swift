//
//  Chat.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Chat: Object {
    var id: UUID
    var name: String?
    var messages: [Message]?
    var participants: [Participant]?
    
    struct Create: Codable {
        var name: String?
        var participants: [Participant.Create]
    }
    
    struct MessageResponse: Object {
        var id: UUID
        var name: String?
    }
    
    struct ParticipantResponse: Object {
        var id: UUID
    }
}
