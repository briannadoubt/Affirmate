//
//  PublicKey.swift
//  AffirmateServer
//
//  Created by Bri on 10/15/22.
//

import Fluent
import Vapor

final class PublicKey: Model, Content, Equatable {
    
    static func == (lhs: PublicKey, rhs: PublicKey) -> Bool {
        lhs.id == rhs.id
    }
    
    static let schema = "public_key"
    
    @ID(key: FieldKey.id) var id: UUID?
    @Field(key: "data") var data: Data
    @Parent(key: "user_id") var user: AffirmateUser
    @Parent(key: "chat_id") var chat: Chat
    
    init() { }
    
    init(id: UUID? = nil, data: Data, user: AffirmateUser.IDValue, chat: Chat.IDValue) {
        self.id = id
        self.data = data
        self.$user.id = user
        self.$chat.id = chat
    }
}

extension PublicKey {
    /// Handle asyncronous database migration; creating and destroying the "ChatParticipant" table.
    struct Migration: AsyncMigration {
        /// The name of the migrator
        var name: String { "PublicKeyMigration" }
        /// Outlines the `public_key` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(PublicKey.schema)
                .id()
                .field("data", .data, .required)
                .field("user_id", .uuid, .required, .references(AffirmateUser.schema, .id))
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .unique(on: "user_id", "chat_id")
                .create()
        }
        /// Destroys the `public_key` table
        func revert(on database: Database) async throws {
            try await database.schema(PublicKey.schema).delete()
        }
    }
}

extension PublicKey {
    struct Create: Content, Validatable {
        
        var data: Data
        
        static func validations(_ validations: inout Validations) {
            validations.add("data", as: Data.self, required: true)
        }
    }
}
