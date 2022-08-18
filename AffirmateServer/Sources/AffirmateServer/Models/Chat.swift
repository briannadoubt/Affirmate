//
//  Chat.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

final class Chat: Model, Content {
    
    static let schema = "chat"
    static let idKey = "chat_id"
    
    @ID(key: FieldKey.id) var id: UUID?
    @Field(key: "name") var name: String?
    @Children(for: \.$chat) var messages: [Message]
    @Children(for: \.$chat) var participants: [Participant]
    
    init() { }
    
    init(id: UUID? = nil, name: String?) {
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
        static func validations(_ validations: inout Validations) {
            validations.add("name", as: String.self)
        }
    }
}

extension Chat {
    struct GetResponse: Content {
        var chat: Chat
        var participants: [Participant]
        var messages: [Message]
    }
}
