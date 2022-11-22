//
//  ChatInvitation.swift
//  AffirmateShared
//
//  Created by Bri on 11/21/22.
//

import Foundation

/// Create a new chat invitation.
public struct ChatInvitationCreate: Codable {
    /// The value denoting the prospective permissions of the invited user.
    public var role: ParticipantRole
    /// The id of the invited user
    public var user: UUID
    
    /// Create a new chat invitation.
    /// - Parameters:
    ///   - role: The value denoting the prospective permissions of the invited user.
    ///   - user: The id of the invited user
    init(role: ParticipantRole, user: UUID) {
        self.role = role
        self.user = user
    }
}

/// The response included in an HTTP GET response.
public struct ChatInvitationResponse: IdentifiableObject {
    /// The id for the database.
    public var id: UUID
    /// The value denoting the prospective permissions of the invited user.
    public var role: ParticipantRole
    /// The id of the invited user.
    public var userId: UUID
    /// The participant id of the user that invited the invited user.
    public var invitedBy: UUID
    /// The username of the user that invited the invited user.
    public var invitedByUsername: String
    /// The chat that the user has been invited to.
    public var chatId: UUID
    /// The name of the chat.
    public var chatName: String?
    /// The usernames of the current participants in the chat.
    public var chatParticipantUsernames: [String]
    /// The globally unique salt for encrypting and decrypting the sealed message content.
    public var chatSalt: Data
    
    /// The response included in an HTTP GET response.
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - role: The value denoting the prospective permissions of the invited user.
    ///   - userId: The id of the invited user.
    ///   - invitedBy: The participant id of the user that invited the invited user.
    ///   - invitedByUsername: The username of the user that invited the invited user.
    ///   - chatId: The chat that the user has been invited to.
    ///   - chatName: The name of the chat.
    ///   - chatParticipantUsernames: The usernames of the current participants in the chat.
    ///   - chatSalt: The globally unique salt for encrypting and decrypting the sealed message content.
    public init(id: UUID, role: ParticipantRole, userId: UUID, invitedBy: UUID, invitedByUsername: String, chatId: UUID, chatName: String?, chatParticipantUsernames: [String], chatSalt: Data) {
        self.id = id
        self.role = role
        self.userId = userId
        self.invitedBy = invitedBy
        self.invitedByUsername = invitedByUsername
        self.chatId = chatId
        self.chatName = chatName
        self.chatParticipantUsernames = chatParticipantUsernames
        self.chatSalt = chatSalt
    }
}

/// Decline a chat
public struct ChatInvitationDecline: Codable {
    /// The id of the chat invitation.
    public var id: UUID
    
    /// Decline a chat
    /// - Parameter id: The id for the database.
    public init(id: UUID) {
        self.id = id
    }
}

/// Join a chat.
public struct ChatInvitationJoin: Codable {
    /// The id of the chat invitation.
    public var id: UUID
    /// The public signing key for the new `Participant`.
    public var signingKey: Data
    /// The public encryption key for the new `Participant`.
    public var encryptionKey: Data
    
    /// Join a chat.
    /// - Parameters:
    ///   - id: The id of the chat invitation.
    ///   - signingKey: The public signing key for the new `Participant`.
    ///   - encryptionKey: The public encryption key for the new `Participant`.
    public init(id: UUID, signingKey: Data, encryptionKey: Data) {
        self.id = id
        self.signingKey = signingKey
        self.encryptionKey = encryptionKey
    }
}
