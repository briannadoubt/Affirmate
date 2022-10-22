//
//  Chat.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

final class Chat: Model, Content, Equatable {
    
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
    
    static let schema = "chat"
    
    @ID(key: FieldKey.id) var id: UUID?
    
    @OptionalField(key: "name") var name: String?
    @Field(key: "salt") var salt: Data
    
    @Children(for: \.$chat) var messages: [Message]
    @Children(for: \.$chat) var participants: [Participant]
    @Children(for: \.$chat) var openInvitations: [ChatInvitation]
    
    init() { }
    
    init(id: UUID, name: String? = nil, salt: Data) {
        self.id = id
        self.name = name
        self.salt = salt
    }
}

extension Chat {
    /// Handle asyncronous database migration; creating and destroying the "Chat" table.
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

extension Chat {
    struct Create: Content, Validatable {
        var id: UUID
        var name: String?
        var participants: [Participant.Create]
        var signingKey: Data
        var encryptionKey: Data
        var salt: Data
        
        static func validations(_ validations: inout Validations) {
            validations.add("id", as: UUID.self, required: true)
            validations.add("name", as: String.self)
            validations.add("participants", as: [Participant.Create].self, required: true)
            validations.add("signingKey", as: Data.self, required: true)
            validations.add("encryptionKey", as: Data.self, required: true)
            validations.add("salt", as: Data.self, required: true)
        }
    }
}

extension Chat {
    
    struct GetResponse: Content {
        var id: UUID
        var name: String?
        var messages: [Message.GetResponse]
        var participants: [Participant.GetResponse]
        var salt: Data
    }
    
    var participantResponse: ParticipantResponse? {
        guard $id.exists, let id else {
            return nil
        }
        return ParticipantResponse(id: id)
    }
    
    struct ParticipantResponse: Content {
        var id: UUID
    }
    
    struct MessageResponse: Content {
        var id: UUID
    }
}
