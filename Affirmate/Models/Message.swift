//
//  Message.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Message: Object {
    var id: UUID
    var text: String?
    var chat: Chat.MessageResponse
    var sender: Participant.GetResponse

    struct Create: Codable {
        var text: String
    }
    
    static var notificationName = Notification.Name("NewMessage")
}
