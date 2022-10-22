//
//  Participant.swift
//  Affirmate
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct Participant: IdentifiableObject {
    var id: UUID //
    var role: Role //
    var user: AffirmateUser.ParticipantResponse //
    var chat: Chat.ParticipantResponse //
    var signingKey: Data //
    var encryptionKey: Data //
    
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
    
    struct Create: Codable, Equatable, Hashable {
        var role: Role
        var user: UUID
    }
    
    struct Draft: Codable, Equatable, Hashable {
        var role: Role
        var user: UUID
    }
}
