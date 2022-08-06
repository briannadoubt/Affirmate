//
//  Message.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Message: Decodable {
    var id: UUID?
    var text: String
    var chat: Chat
    var sender: User

    struct Create: Encodable {
        var text: String
    }
}
