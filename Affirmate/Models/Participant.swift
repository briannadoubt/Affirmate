//
//  Participant.swift
//  Affirmate
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Relation: Object {
    var id: UUID
}

struct Participant: Object {
    var id: UUID?
    var role: Role
    var user: AffirmateUser.Public
    var chat: Relation
    
    enum Role: String, CaseIterable, Codable, Hashable, Equatable, Identifiable {
        case admin
        case participant
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .admin:
                return "Admin"
            case .participant:
                return "Participant"
            }
        }
    }
    
    struct Create: Codable, Hashable {
        var role: Role
        var user: UUID
    }
    
    struct GetResponse: Object {
        var id: UUID
        var role: Role
        var user: AffirmateUser.Public
        var chat: Chat.ParticipantResponse
    }
}
