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
    var users: [User]?
    
    struct Create: Codable {
        var name: String?
    }
}
