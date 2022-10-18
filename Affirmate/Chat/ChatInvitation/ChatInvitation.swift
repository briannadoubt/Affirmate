//
//  ChatInvitation.swift
//  Affirmate
//
//  Created by Bri on 10/11/22.
//

import Foundation

struct ChatInvitation: Object {
    var id: UUID
    var role: Participant.Role
    var userId: UUID
    var invitedBy: UUID
    var invitedByUsername: String
    var chatId: UUID
    var chatName: String?
    var chatParticipantUsernames: [String]
    var invitedBySignedPreKey: Data
    var invitedByIdentity: Data
    var preKey: Data
    
    struct Join: Codable, Identifiable {
        var id: UUID
        var signedPreKey: Data
    }
    
    struct Decline: Codable, Identifiable {
        var id: UUID
    }
}
