//
//  ChatInvitation.swift
//  AffirmateServer
//
//  Created by Bri on 8/27/22.
//

import AffirmateShared
import Fluent
import Vapor

/// An invitation to join a chat, from one user of Affirmate to another.
final class ChatInvitation: Model, Content {
    
    /// The name of the table on the database.
    static let schema = "chat_invitations"
    
    /// The id for the database.
    @ID(key: FieldKey.id) var id: UUID?
    
    /// The value denoting the prospective permissions of the invited user.
    @Field(key: "role") var role: ParticipantRole
    
    /// The invited user.
    @Parent(key: "user_id") var user: User
    
    /// The participant that invited the invited user.
    @Parent(key: "invited_by_id") var invitedBy: Participant
    
    /// The chat that the user has been invited to.
    @Parent(key: "chat_id") var chat: Chat
    
    /// Conform to `Model`.
    init() { }
    
    /// Initialize a `ChatInvitation` for the database.
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - role: The value denoting the prospective permissions of the invited user.
    ///   - user: The id of the invited user
    ///   - invitedBy: The participant that invited the invited user.
    ///   - chat: The chat that the user has been invited to.
    init(id: UUID? = nil, role: ParticipantRole, user: User.IDValue, invitedBy: Participant.IDValue, chat: Chat.IDValue) {
        self.id = id
        self.role = role
        self.$user.id = user
        self.$invitedBy.id = invitedBy
        self.$chat.id = chat
    }
    
    /// Handle asyncronous database migration; creating and destroying the "ChatParticipant" table.
    struct Migration: AsyncMigration {
        
        /// The name of the migrator
        var name: String { "ChatInvitationMigration" }
        
        /// Outlines the `chat-participants` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(ChatInvitation.schema)
                .id()
                .field("role", .string, .required)
                .field("user_id", .uuid, .required, .references(User.schema, .id))
                .field("invited_by_id", .uuid, .required, .references(Participant.schema, .id))
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .unique(on: "user_id", "chat_id")
                .create()
        }
        
        /// Destroys the `chat_participants` table
        func revert(on database: Database) async throws {
            try await database.schema(ChatInvitation.schema).delete()
        }
    }
}

extension ChatInvitationCreate: Content, Validatable {
    /// Conform to `Validatable`
    /// - Parameter validations: The validations to validate.
    public static func validations(_ validations: inout Validations) {
        validations.add("role", as: ParticipantRole.self, required: true)
        validations.add("user", as: UUID.self, required: true)
    }
}

extension ChatInvitationResponse: Content { }

extension ChatInvitationDecline: Content, Validatable {
    /// Conform to `Validatable`
    /// - Parameter validations: The validations to validate.
    public static func validations(_ validations: inout Validations) {
        validations.add("id", as: UUID.self, required: true, customFailureDescription: "The ChatInvitation ID is required.")
    }
}

extension ChatInvitationJoin: Content, Validatable {
    /// Conform to `Validatable`
    /// - Parameter validations: The validations to validate.
    public static func validations(_ validations: inout Validations) {
        validations.add("id", as: UUID.self, required: true, customFailureDescription: "The ChatInvitation ID is required.")
        validations.add("signingKey", as: Data.self, required: true)
        validations.add("encryptionKey", as: Data.self, required: true)
    }
}
