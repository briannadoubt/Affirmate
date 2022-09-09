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
    @Field(key: "name") var name: String?
    @Children(for: \.$chat) var messages: [Message]
    @Children(for: \.$chat) var participants: [Participant]
//    @Children(for: \.$chat) var openInvitations: [ChatInvitation]
    
    init() { }
    
    init(id: UUID? = nil, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

extension Chat {
    /// Handle asyncronous database migration; creating and destroying the "Chat" table.
    struct Migration: AsyncMigration {
        /// The name of the migrator
        var name: String { "ChatMigration" }
        /// Outlines the `chats` table schema
        func prepare(on database: Database) async throws {
            try await database.schema("chat")
                .id()
                .field("name", .string)
                .create()
        }
        /// Destroys the `chats` table
        func revert(on database: Database) async throws {
            try await database.schema("chat").delete()
        }
    }
}

extension Chat {
    struct Create: Content, Validatable {
        var name: String?
        var participants: [Participant.Create]
        static func validations(_ validations: inout Validations) {
            validations.add("name", as: String.self)
            validations.add("participants", as: [Participant.Create].self)
        }
    }
}

extension Chat {
    
    struct GetResponse: Content {
        var id: UUID
        var name: String?
        var messages: [Message.GetResponse]
        var participants: [Participant.GetResponse]
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
