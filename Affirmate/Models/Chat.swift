//
//  Chat.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Chat: Codable {
    var id: UUID?
    var name: String
    
    struct Create: Encodable {
        var name: String?
    }
    
    struct GetResponse: Decodable {
        var chat: Chat
        var participants: [ChatParticipant]
        var messages: [Message]
    }
}
