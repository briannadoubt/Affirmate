//
//  Message.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor
import APNS

final class Message: Model, Content {
    
    static let schema = "message"
    
    @ID(key: FieldKey.id) var id: UUID?
    @Field(key: "text") var text: String
    @Parent(key: "chat_id") var chat: Chat
    @Parent(key: "sender_id") var sender: AffirmateUser
    
    init() { }
    
    init(id: UUID? = nil, text: String, chat: Chat.IDValue, sender: AffirmateUser.IDValue) {
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
                .field("text", .string)
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .field("sender_id", .uuid, .required, .references(AffirmateUser.schema, .id))
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

extension Message {
    var notification: Notification {
        Notification(message: self)
    }
    struct Notification: APNSwiftNotification {
        let message: Message
        var aps: APNSwiftPayload {
            APNSwiftPayload(
                alert: alert,
                badge: 1,
                sound: .normal("ReceivedMessage.caf"),
                category: "ReceivedMessage",
                interruptionLevel: "active",
                relevanceScore: 1
            )
        }
        var alert: APNSwiftAlert {
            APNSwiftAlert(
                title: "\(message.sender.username) sent you a message!",
                subtitle: message.chat.name,
                body: message.text
            )
        }
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

extension Message {
    struct GetResponse: Content {
        var text: String
        var chat: Chat.GetResponse
        var sender: AffirmateUser.GetResponse
    }
}
