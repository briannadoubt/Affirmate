//
//  AffirmateUser.swift
//  AffirmateServer
//
//  Created by Bri on 7/3/22.
//

import Foundation

struct AffirmateUser: IdentifiableObject {
    var id: UUID
    var firstName: String
    var lastName: String
    var username: String
    var email: String
    var chatInvitations: [ChatInvitation]
    var created: Date?
    var updated: Date?
    
    init(id: UUID, firstName: String, lastName: String, username: String, email: String, chatInvitations: [ChatInvitation]) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
        self.chatInvitations = chatInvitations
    }
    
    struct LoginResponse: Decodable {
        var sessionToken: SessionToken
        var user: AffirmateUser
    }
    
    /// The post parameter used to create a new user
    struct Create: Encodable {
        var firstName: String
        var lastName: String
        var username: String
        var email: String
        var password: String
        var confirmPassword: String
    }
    
    struct Public: IdentifiableObject {
        var id: UUID
        var username: String
    }
    
    struct SessionTokenResponse: Codable {
        var id: UUID
    }
    
    struct ParticipantResponse: IdentifiableObject {
        var id: UUID //
        var username: String //
    }
}
