//
//  PreKey.swift
//  AffirmateServer
//
//  Created by Bri on 10/15/22.
//

import Fluent
import Vapor

final class PreKey: Model, Content, Equatable {
    
    static func == (lhs: PreKey, rhs: PreKey) -> Bool {
        lhs.id == rhs.id
    }
    
    static let schema = "pre_key"
    
    @ID(key: FieldKey.id) var id: UUID?
    @Field(key: "data") var data: Data
    @Parent(key: "user_id") var user: AffirmateUser
    @Parent(key: "chat_id") var chat: Chat
    @OptionalParent(key: "invitation_id") var invitation: ChatInvitation?
    
    init() { }
    
    init(id: UUID? = nil, data: Data, user: AffirmateUser.IDValue, chat: Chat.IDValue, invitation: ChatInvitation.IDValue? = nil) {
        self.id = id
        self.data = data
        self.$user.id = user
        self.$chat.id = chat
        self.$invitation.id = invitation
    }
}

extension PreKey {
    /// Handle asyncronous database migration; creating and destroying the "ChatParticipant" table.
    struct Migration: AsyncMigration {
        /// The name of the migrator
        var name: String { "PreKeyMigration" }
        /// Outlines the `pre_key` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(PreKey.schema)
                .id()
                .field("data", .data, .required)
                .field("user_id", .uuid, .required, .references(AffirmateUser.schema, .id))
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .field("invitation_id", .uuid, .references(ChatInvitation.schema, .id, onDelete: .cascade, onUpdate: .cascade))
                .create()
        }
        /// Destroys the `pre_key` table
        func revert(on database: Database) async throws {
            try await database.schema(PreKey.schema).delete()
        }
    }
}

extension PreKey {
    struct ChatGetResponse: Content {
        var id: UUID
        var data: Data
        var invitation: ChatInvitation.GetResponse
    }
}
