//
//  Message.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor
import APNS

final class Message: Model, Content, Equatable {
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
    
    static let schema = "message"
    
    @ID(key: FieldKey.id) var id: UUID?
    @OptionalField(key: "text") var text: Data?
    @Parent(key: "chat_id") var chat: Chat
    @Parent(key: "sender_id") var sender: Participant
    @Timestamp(key: "created", on: .create) var created: Date?
    @Timestamp(key: "updated", on: .update) var updated: Date?
    
    init() { }
    
    init(id: UUID? = nil, text: Data? = nil, chat: Chat.IDValue, sender: Participant.IDValue) {
        self.id = id
        self.text = text
        self.$chat.id = chat
        self.$sender.id = sender
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
                .field("text", .data)
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .field("sender_id", .uuid, .required, .references(Participant.schema, .id))
                .field("created", .datetime, .required)
                .field("updated", .datetime, .required)
                .create()
        }
        /// Destroys the `messages` table
        func revert(on database: Database) async throws {
            try await database.schema(Message.schema).delete()
        }
    }
}

extension Message {
    struct Create: Content, Validatable, Equatable, Hashable {
        var text: Data
        static func validations(_ validations: inout Validations) {
            validations.add("text", as: Data.self, is: !.empty)
        }
    }
}

extension Message {
    struct GetResponse: Content {
        var id: UUID
        var text: Data?
        var chat: Chat.MessageResponse
        var sender: Participant.GetResponse
        var created: Date?
        var updated: Date?
    }
}

extension APNSwiftPayload {
    enum InturruptionLevel {
        static let passive = "passive"
        static let active = "active"
        static let timeSensitive = "time-sensitive"
        static let critical = "critical"
    }
}
