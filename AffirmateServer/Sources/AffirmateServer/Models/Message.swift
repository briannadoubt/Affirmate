//
//  Message.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

final class Message: Model, Content {
    
    static let schema = "message"
    static let idKey = "message_id"
    
    @ID(key: FieldKey.id) var id: UUID?
    @Field(key: "text") var text: String
    @Parent(key: "chat_id") var chat: Chat
    @Parent(key: "sender_id") var sender: User
    
    init() { }
    
    init(id: UUID? = nil, text: String, chat: Chat, sender: User) {
        self.id = id
        self.text = text
        self.chat = chat
        self.sender = sender
    }
}

extension Message {
    /// Handle asyncronous database migration; creating and destroying the `messages` table.
    struct Migration: AsyncMigration {
        /// The name of the migrator
        var name: String { "MessageMigration" }
        /// Outlines the `messages` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(Message.schema)
                .id()
                .field("text", .string)
                .field("chat_id", .uuid, .required, .references(Chat.schema, "id"))
                .field("sender_id", .uuid, .required, .references(User.schema, .id))
                .create()
        }
        /// Destroys the `messages` table
        func revert(on database: Database) async throws {
            try await database.schema(Message.schema).delete()
        }
    }
}

extension Message {
    struct Create: Content, Validatable {
        var text: String
        static func validations(_ validations: inout Validations) {
            validations.add("text", as: String.self, is: !.empty)
        }
    }
}
