//
//  Participant.swift
//  Affirmate
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Relation: Object {
    var id: UUID?
}

struct Participant: Object {
    var id: UUID?
    var role: Role
    var user: User
    var chat: Relation
    
    enum Role: String, CaseIterable, Codable, Hashable, Equatable {
        case admin
        case participant
    }
}
