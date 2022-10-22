//
//  ChatInvitation.swift
//  AffirmateServer
//
//  Created by Bri on 8/27/22.
//

import Fluent
import Vapor

final class ChatInvitation: Model, Content, Equatable {
    
    static func == (lhs: ChatInvitation, rhs: ChatInvitation) -> Bool {
        lhs.id == rhs.id
    }
    
    static let schema = "chat_invitations"
    
    @ID(key: FieldKey.id) var id: UUID?
    
    @Field(key: "role") var role: Participant.Role
    
    @Parent(key: "user_id") var user: AffirmateUser
    @Parent(key: "invited_by_id") var invitedBy: Participant
    @Parent(key: "chat_id") var chat: Chat
    
    init() { }
    
    init(
        id: UUID? = nil,
        role: Participant.Role,
        user: AffirmateUser.IDValue,
        invitedBy: Participant.IDValue,
        chat: Chat.IDValue
    ) {
        self.id = id
        self.role = role
        self.$user.id = user
        self.$invitedBy.id = invitedBy
        self.$chat.id = chat
    }
}

extension ChatInvitation {
    struct Create: Content, Validatable {
        var role: Participant.Role
        var user: UUID
        static func validations(_ validations: inout Validations) {
            validations.add("role", as: Participant.Role.self, required: true)
            validations.add("user", as: UUID.self, required: true)
        }
    }
    struct Join: Content, Validatable {
        var id: UUID
        var signingKey: Data
        var encryptionKey: Data
        static func validations(_ validations: inout Validations) {
            validations.add("id", as: UUID.self, required: true, customFailureDescription: "The ChatInvitation ID is required.")
            validations.add("signingKey", as: Data.self, required: true)
            validations.add("encryptionKey", as: Data.self, required: true)
        }
    }
    struct Decline: Content, Validatable {
        var id: UUID
        static func validations(_ validations: inout Validations) {
            validations.add("id", as: UUID.self, required: true, customFailureDescription: "The ChatInvitation ID is required.")
        }
    }
}

extension ChatInvitation {
    /// Handle asyncronous database migration; creating and destroying the "ChatParticipant" table.
    struct Migration: AsyncMigration {
        /// The name of the migrator
        var name: String { "ChatInvitationMigration" }
        /// Outlines the `chat-participants` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(ChatInvitation.schema)
                .id()
                .field("role", .string, .required)
                .field("user_id", .uuid, .required, .references(AffirmateUser.schema, .id))
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

extension ChatInvitation {
    struct GetResponse: Content, Equatable, Codable {
        var id: UUID
        var role: Participant.Role
        var userId: UUID
        var invitedBy: UUID
        var invitedByUsername: String
        var chatId: UUID
        var chatName: String?
        var chatParticipantUsernames: [String]
        var chatSalt: Data
    }
}
