//
//  Participant.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import AffirmateShared
import Fluent
import Vapor

/// A participant of a chat
final class Participant: Model, Content {
    
    /// The name of the table on the database.
    static let schema = "participant"
    
    /// The id for the database.
    @ID(key: FieldKey.id) var id: UUID?
    
    /// The value denoting the permissions of the user.
    @Field(key: "role") var role: ParticipantRole
    
    /// The user who operates this participant.
    @Parent(key: "user_id") var user: User
    
    /// The chat that this participant is a part of.
    @Parent(key: "chat_id") var chat: Chat
    
    /// The public keys that enable encryption/decryption in this chat.
    @Parent(key: "public_key_id") var publicKey: PublicKey
    
    /// Conform to `Model`.
    init() { }
    
    /// Initialize a new `Participant` for the database
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - role: The value denoting the permissions of the user.
    ///   - user: The user who operates this participant.
    ///   - chat: The chat that this participant is a part of.
    ///   - publicKey: The public keys that enable encryption/decryption in this chat.
    init(id: UUID? = nil, role: ParticipantRole = .participant, user: User.IDValue, chat: User.IDValue, publicKey: PublicKey.IDValue) {
        self.id = id
        self.role = role
        self.$user.id = user
        self.$chat.id = chat
        self.$publicKey.id = publicKey
    }
    
    /// Handle asyncronous database migration; creating and destroying the "ChatParticipant" table.
    struct Migration: AsyncMigration {
        
        /// The name of the migrator
        var name: String { "ParticipantMigration" }
        
        /// Outlines the `chat-participants` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(Participant.schema)
                .id()
                .field("role", .string, .required)
                .field("user_id", .uuid, .required, .references(User.schema, .id))
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .field("public_key_id", .uuid, .required, .references(PublicKey.schema, .id))
                .unique(on: "user_id", "chat_id")
                .create()
        }
       
        /// Destroys the `chat_participants` table
        func revert(on database: Database) async throws {
            try await database.schema(Participant.schema).delete()
        }
    }
}

extension ParticipantCreate: Content, Validatable {
    /// Conform to `Validatable`
    /// - Parameter validations: The validations to validate.
    public static func validations(_ validations: inout Validations) {
        validations.add("role", as: String.self, is: !.empty, required: true)
        validations.add("user", as: UUID.self, required: true)
    }
}

extension ParticipantResponse: Content { }
