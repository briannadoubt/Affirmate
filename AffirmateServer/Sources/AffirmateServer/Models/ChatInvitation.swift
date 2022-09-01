//
//  ChatInvitation.swift
//  AffirmateServer
//
//  Created by Bri on 8/27/22.
//

import Fluent
import Vapor

final class ChatInvitation: Model, Content {
    
    static let schema = "chat_invitation"
    
    @ID(key: FieldKey.id) var id: UUID?
    @Field(key: "role") var role: Participant.Role
    @Parent(key: "user_id") var user: User
    @Parent(key: "chat_id") var chat: Chat
    
    init() { }
    
    init(id: UUID? = nil, role: Participant.Role, user: User.IDValue, chat: Chat.IDValue) {
        self.id = id
        self.role = role
        self.$user.id = user
        self.$chat.id = chat
    }
}

extension ChatInvitation {
    struct Create: Content, Validatable {
        var role: Participant.Role
        var user: UUID
        static func validations(_ validations: inout Validations) {
            validations.add("role", as: String.self, is: !.empty)
            validations.add("user", as: UUID.self)
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
            try await database.schema(Participant.schema)
                .id()
                .field("role", .string, .required)
                .field("user_id", .uuid, .required, .references(User.schema, .id))
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .unique(on: "user_id", "chat_id")
                .create()
        }
        /// Destroys the `chat_participants` table
        func revert(on database: Database) async throws {
            try await database.schema(Participant.schema).delete()
        }
    }
}

extension ChatInvitation {
    var getResponse: GetResponse {
        get throws {
            try GetResponse(role: role, user: user.getResponse, chat: chat.participantResponse)
        }
    }
    struct GetResponse: Content {
        var role: Participant.Role
        var user: User.GetResponse
        var chat: Chat.ParticipantResponse?
    }
}

extension Collection where Element == ChatInvitation {
    var getResponse: [ChatInvitation.GetResponse] {
        get throws {
            try map { try $0.getResponse }
        }
    }
}
