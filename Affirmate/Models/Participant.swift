//
//  Participant.swift
//  Affirmate
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Participant: Object {
    var id: UUID?
    var role: Role
    var user: Representation
    var chat: Chat
    
    enum Role: String, CaseIterable, Codable, Hashable, Equatable {
        case admin
        case participant
    }
}
