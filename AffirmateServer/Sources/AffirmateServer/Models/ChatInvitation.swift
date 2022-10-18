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
    @Field(key: "invited_by_signed_pre_key") var invitedBySignedPreKey: Data
    @Field(key: "invited_by_identity") var invitedByIdentity: Data
    
    @Parent(key: "user_id") var user: AffirmateUser
    @Parent(key: "invited_by_id") var invitedBy: AffirmateUser
    @Parent(key: "chat_id") var chat: Chat
    
    @OptionalChild(for: \.$invitation) var preKey: PreKey?
    
    init() { }
    
    init(
        id: UUID? = nil,
        role: Participant.Role,
        invitedBySignedPreKey: Data,
        invitedByIdentity: Data,
        user: AffirmateUser.IDValue,
        invitedBy: AffirmateUser.IDValue,
        chat: Chat.IDValue
    ) {
        self.id = id
        self.role = role
        self.invitedBySignedPreKey = invitedBySignedPreKey
        self.invitedByIdentity = invitedByIdentity
        self.$user.id = user
        self.$invitedBy.id = invitedBy
        self.$chat.id = chat
    }
}

extension ChatInvitation {
    struct Create: Content, Validatable {
        var role: Participant.Role
        var user: UUID
        var invitedBySignedPreKey: Data
        var invitedByIdentity: Data
        static func validations(_ validations: inout Validations) {
            validations.add("role", as: Participant.Role.self, required: true)
            validations.add("user", as: UUID.self, required: true)
            validations.add("invitedBySignedPreKey", as: Data.self, required: true)
            validations.add("invitedByIdentity", as: Data.self, required: true)
        }
    }
    struct Join: Content, Validatable {
        var id: UUID
        var signedPreKey: Data
        static func validations(_ validations: inout Validations) {
            validations.add("id", as: UUID.self, required: true, customFailureDescription: "The ChatInvitation ID is required.")
            validations.add("signedPreKey", as: Data.self, required: true)
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
                .field("invited_by_signed_pre_key", .data, .required)
                .field("invited_by_identity", .data, .required)
                .field("user_id", .uuid, .required, .references(AffirmateUser.schema, .id))
                .field("invited_by_id", .uuid, .required, .references(AffirmateUser.schema, .id))
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
        var invitedBySignedPreKey: Data
        var invitedByIdentity: Data
        var preKey: Data?
    }
}
