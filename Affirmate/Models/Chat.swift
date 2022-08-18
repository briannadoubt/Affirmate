//
//  Chat.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Chat: Object, UpdateObject {
    var id: UUID?
    var name: String
    var participants: [Participant]?
    var messages: [Message]?
    
    struct Create: CreateObject {
        var name: String?
    }
}
