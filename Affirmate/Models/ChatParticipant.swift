//
//  ChatParticipant.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct ChatParticipant: Decodable {
    var id: UUID?
    var role: Role
    var user: User
    var chat: Chat
    
    enum Role: String, CaseIterable, Codable, Hashable {
        case admin
        case participant
    }
}
