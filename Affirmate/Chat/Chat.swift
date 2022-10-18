//
//  Chat.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation
import SignalProtocol

struct Chat: Codable, Equatable, Identifiable {
    
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
    
    var id: UUID
    var name: String?
    var messages: [Message]?
    var participants: [Participant]?
    var preKey: Data
    
    struct Create: Codable {
        var id: UUID
        var name: String?
        var participants: [Participant.Create]
        var publicKey: Data
        var preKeys: [Data]
        var signedPreKey: Data
    }
    
    struct MessageResponse: Object {
        var id: UUID
        var name: String?
    }
    
    struct ParticipantResponse: Object {
        var id: UUID
    }
}
