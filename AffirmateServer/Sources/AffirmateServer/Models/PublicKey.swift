//
//  PublicKey.swift
//  AffirmateServer
//
//  Created by Bri on 10/15/22.
//

import Fluent
import Vapor

final class PublicKey: Model, Content {
    
    /// The name of the table on the database.
    static let schema = "public_key"
    
    /// The id for the database.
    @ID(key: FieldKey.id) var id: UUID?
    
    /// The public signing key data.
    @Field(key: "signing_key") var signingKey: Data
    
    /// The public encryption key data.
    @Field(key: "encryption_key") var encryptionKey: Data
    
    /// The user who owns thess public keys
    @Parent(key: "user_id") var user: AffirmateUser
    
    /// The chat for which these keys encrypt/decrypt.
    @Parent(key: "chat_id") var chat: Chat
    
    /// Conform to `Model`.
    init() { }
    
    /// Initialize a new `PublicKey` for the database
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - signingKey: The public signing key data.
    ///   - encryptionKey: The public encryption key data.
    ///   - user: The id of the user who owns thess public keys
    ///   - chat: The id of the chat for which these keys encrypt/decrypt.
    init(id: UUID? = nil, signingKey: Data, encryptionKey: Data, user: AffirmateUser.IDValue, chat: Chat.IDValue) {
        self.id = id
        self.signingKey = signingKey
        self.encryptionKey = encryptionKey
        self.$chat.id = chat
        self.$user.id = user
    }
    
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
    
    /// Create a new public key
    struct Create: Content, Validatable, Equatable, Hashable {
        
        /// The public signing key data.
        var signingKey: Data
        
        /// The public encryption key data.
        var encryptionKey: Data
        
        /// Conform to `Validatable`
        /// - Parameter validations: The validations to validate.
        static func validations(_ validations: inout Validations) {
            validations.add("signingKey", as: Data.self, required: true)
            validations.add("encryptionKey", as: Data.self, required: true)
        }
    }
}
