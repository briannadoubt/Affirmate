//
//  Participant.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

/// A participant of a chat
final class Participant: Model, Content {
    
    /// The name of the table on the database.
    static let schema = "participant"
    
    /// The id for the database.
    @ID(key: FieldKey.id) var id: UUID?
    
    /// The value denoting the permissions of the user.
    @Field(key: "role") var role: Role
    
    /// The user who operates this participant.
    @Parent(key: "user_id") var user: AffirmateUser
    
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
    init(id: UUID? = nil, role: Participant.Role = .participant, user: AffirmateUser.IDValue, chat: AffirmateUser.IDValue, publicKey: PublicKey.IDValue) {
        self.id = id
        self.role = role
        self.$user.id = user
        self.$chat.id = chat
        self.$publicKey.id = publicKey
    }
    
    /// The value denoting the permissions of the user.
    enum Role: String, CaseIterable, Codable, Hashable {
        
        /// Has permissions to update and delete messages, or add new participants to the chat.
        case admin
        
        /// Only has permissions to send and read messages.
        case participant
    }
    
    /// Create a new participant for a chat.
    struct Create: Content, Validatable, Equatable, Hashable {
        
        /// The value denoting the permissions of the user.
        var role: Role
        
        /// The id of the user who operates this participant.
        var user: UUID
        
        /// Conform to `Validatable`
        /// - Parameter validations: The validations to validate.
        static func validations(_ validations: inout Validations) {
            validations.add("role", as: String.self, is: !.empty, required: true)
            validations.add("user", as: UUID.self, required: true)
        }
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
                .field("user_id", .uuid, .required, .references(AffirmateUser.schema, .id))
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
    
    /// The response included in an HTTP GET response.
    struct GetResponse: Content {
        
        /// The id for the database.
        var id: UUID
        
        /// The value denoting the permissions of the user.
        var role: Role
        
        /// The user who operates this participant.
        var user: AffirmateUser.ParticipantResponse
        
        /// The chat that this participant is a part of.
        var chat: Chat.ParticipantResponse
        
        /// The public signing key for the chat.
        var signingKey: Data
        
        /// The public encryption key for the chat.
        var encryptionKey: Data
    }
}
