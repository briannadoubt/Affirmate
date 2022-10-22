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
    @Field(key: "signing_key") var signingKey: Data
    @Field(key: "encryption_key") var encryptionKey: Data
    @Parent(key: "user_id") var user: AffirmateUser
    @Parent(key: "chat_id") var chat: Chat
    
    init() { }
    
    init(id: UUID? = nil, signingKey: Data, encryptionKey: Data, user: AffirmateUser.IDValue, chat: Chat.IDValue) {
        self.id = id
        self.signingKey = signingKey
        self.encryptionKey = encryptionKey
        self.$chat.id = chat
        self.$user.id = user
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
                .field("signing_key", .data, .required)
                .field("encryption_key", .data, .required)
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .field("user_id", .uuid, .required, .references(AffirmateUser.schema, .id))
                .unique(on: "chat_id", "user_id")
                .create()
        }
        /// Destroys the `public_key` table
        func revert(on database: Database) async throws {
            try await database.schema(PublicKey.schema).delete()
        }
    }
}

extension PublicKey {
    struct Create: Content, Validatable, Equatable, Hashable {
        var signingKey: Data
        var encryptionKey: Data
        static func validations(_ validations: inout Validations) {
            validations.add("signingKey", as: Data.self, required: true)
            validations.add("encryptionKey", as: Data.self, required: true)
        }
    }
}
