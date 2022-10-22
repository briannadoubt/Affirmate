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
    @Field(key: "ephemeralPublicKeyData") var ephemeralPublicKeyData: Data
    @Field(key: "ciphertext") var ciphertext: Data
    @Field(key: "signature") var signature: Data
    @Parent(key: "chat_id") var chat: Chat
    @Parent(key: "sender_id") var sender: Participant
    @Parent(key: "recipient_id") var recipient: Participant
    @Timestamp(key: "created", on: .create, format: .iso8601) var created: Date?
    @Timestamp(key: "updated", on: .update, format: .iso8601) var updated: Date?
    
    init() { }
    
    init(id: UUID? = nil, ephemeralPublicKeyData: Data, ciphertext: Data, signature: Data, chat: Chat.IDValue, sender: Participant.IDValue, recipient: Participant.IDValue) {
        self.id = id
        self.ephemeralPublicKeyData = ephemeralPublicKeyData
        self.ciphertext = ciphertext
        self.signature = signature
        self.$chat.id = chat
        self.$sender.id = sender
        self.$recipient.id = recipient
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
                .field("ephemeralPublicKeyData", .data)
                .field("ciphertext", .data)
                .field("signature", .data)
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .field("sender_id", .uuid, .required, .references(Participant.schema, .id))
                .field("recipient_id", .uuid, .required, .references(Participant.schema, .id))
                .field("created", .string)
                .field("updated", .string)
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
        var sealed: Sealed
        var recipient: UUID
        static func validations(_ validations: inout Validations) {
            validations.add("sealed", as: Sealed.self, required: true)
            validations.add("recipient", as: UUID.self, required: true)
        }
    }
}

extension Message {
    struct GetResponse: Content {
        var id: UUID
        var text: Sealed
        var chat: Chat.MessageResponse
        var sender: Participant.GetResponse
        var recipient: Participant.GetResponse
        var created: Date?
        var updated: Date?
    }
    
    struct Sealed: Codable {
        internal init(ephemeralPublicKeyData: Data, ciphertext: Data, signature: Data) {
            self.ephemeralPublicKeyData = ephemeralPublicKeyData
            self.ciphertext = ciphertext
            self.signature = signature
        }
        
        var ephemeralPublicKeyData: Data
        var ciphertext: Data
        var signature: Data
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
