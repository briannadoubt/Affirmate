//
//  Message.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Message: Object {
    var id: UUID
    var text: Data?
    var chat: Chat.MessageResponse
    var sender: Participant
    var created: Date?
    var updated: Date?
    
    enum CodingKeys: CodingKey {
        case id
        case text
        case chat
        case sender
        case created
        case updated
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.chat = try container.decode(Chat.MessageResponse.self, forKey: .chat)
        self.sender = try container.decode(Participant.self, forKey: .sender)
        self.created = try container.decodeIfPresent(Date.self, forKey: .created)
        self.updated = try container.decodeIfPresent(Date.self, forKey: .updated)
        self.text = try container.decodeIfPresent(Data.self, forKey: .text)
    }
    
    init(id: UUID, text: Data? = nil, chat: Chat.MessageResponse, sender: Participant, created: Date? = nil, updated: Date? = nil) {
        self.id = id
        self.text = text
        self.chat = chat
        self.sender = sender
        self.created = created
        self.updated = updated
    }

    struct Create: Codable {
        var text: Data
    }
    
    static var notificationName = Notification.Name("NewMessage")
}
