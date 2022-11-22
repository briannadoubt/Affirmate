//
//  Chat.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import AffirmateShared
import Fluent
import Vapor

/// A chat between users of Affirmate. Stored in the database.
final class Chat: Model, Content {
    
    /// The name of the table on the database.
    static let schema = "chat"
    
    /// The id for the database.
    @ID(key: FieldKey.id) var id: UUID?
    
    /// The name of the chat.
    @OptionalField(key: "name") var name: String?
    
    /// The globally unique salt for encrypting and decrypting the sealed message content.
    @Field(key: "salt") var salt: Data
    
    /// The messages of the chat.
    @Children(for: \.$chat) var messages: [Message]
    
    /// The participants of the chat.
    @Children(for: \.$chat) var participants: [Participant]
    
    /// The open invitations of the chat.
    @Children(for: \.$chat) var openInvitations: [ChatInvitation]
    
    /// Conform to `Model`
    init() { }
    
    /// Initialize a new chat for the database.
    /// - Parameters:
    ///   - id: The id for the database
    ///   - name: The name of the chat
    ///   - salt: The globally unique salt for encrypting and decrypting the sealed message content.
    init(id: UUID, name: String? = nil, salt: Data) {
        self.id = id
        self.name = name
        self.salt = salt
    }

    /// Handle asyncronous database migration; creating and destroying the `chat` table.
    struct Migration: AsyncMigration {
        
        /// The name of the migrator
        var name: String { "ChatMigration" }
        
        /// Outlines the `chats` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(Chat.schema)
                .id()
                .field("name", .string)
                .field("salt", .data)
                .create()
        }
        
        /// Destroys the `chats` table
        func revert(on database: Database) async throws {
            try await database.schema(Chat.schema).delete()
        }
    }
}

extension ChatCreate: Content, Validatable {
    /// Conform to `Validatable`
    /// - Parameter validations: The validations to validate.
    public static func validations(_ validations: inout Validations) {
        validations.add("id", as: UUID.self, required: true)
        validations.add("name", as: String.self)
        validations.add("participants", as: [ParticipantCreate].self, required: true)
        validations.add("signingKey", as: Data.self, required: true)
        validations.add("encryptionKey", as: Data.self, required: true)
        validations.add("salt", as: Data.self, required: true)
    }
}

extension ChatResponse: Content { }

extension ChatParticipantResponse: Content { }

extension ChatMessageResponse: Content { }
