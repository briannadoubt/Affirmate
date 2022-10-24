//
//  Message.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor
import APNS

/// A message from a user of Affirmate to a chat between other users of Affirmate.
final class Message: Model, Content {
    
    /// The name of the table on the database.
    static let schema = "message"
    
    /// The id for the database.
    @ID(key: FieldKey.id) var id: UUID?
    
    /// The ephemeral public key portion of the encrypted message.
    @Field(key: "ephemeralPublicKeyData") var ephemeralPublicKeyData: Data
    
    /// The ciphertext portion of the encrypted message.
    @Field(key: "ciphertext") var ciphertext: Data
    
    /// The signature portion of the encrypted message.
    @Field(key: "signature") var signature: Data
    
    /// The chat that this message was sent to.
    @Parent(key: "chat_id") var chat: Chat
    
    /// The participant that sent this message.
    @Parent(key: "sender_id") var sender: Participant
    
    /// The recipient of this message.
    @Parent(key: "recipient_id") var recipient: Participant
    
    /// The timestamp that the message was created.
    @Timestamp(key: "created", on: .create, format: .iso8601) var created: Date?
    
    /// The timestamp that the message was last updated.
    @Timestamp(key: "updated", on: .update, format: .iso8601) var updated: Date?
    
    /// Conform to `Model`.
    init() { }
    
    /// Initialize a new message for the database.
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - ephemeralPublicKeyData: The ephemeral public key portion of the encrypted message.
    ///   - ciphertext: The ciphertext portion of the encrypted message.
    ///   - signature: The signature portion of the encrypted message.
    ///   - chat: The id of the chat this message was sent to.
    ///   - sender: The od of the participant that sent this message.
    ///   - recipient: The id of the recipient of this message.
    init(id: UUID? = nil, ephemeralPublicKeyData: Data, ciphertext: Data, signature: Data, chat: Chat.IDValue, sender: Participant.IDValue, recipient: Participant.IDValue) {
        self.id = id
        self.ephemeralPublicKeyData = ephemeralPublicKeyData
        self.ciphertext = ciphertext
        self.signature = signature
        self.$chat.id = chat
        self.$sender.id = sender
        self.$recipient.id = recipient
    }
    
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
    
    /// Create a new message
    struct Create: Content, Validatable {
        
        /// The sealed content of the message.
        var sealed: Sealed
        
        /// The id of the recipient participant of the message.
        var recipient: UUID
        
        /// Conform to `Validatable`
        /// - Parameter validations: The validations to validate.
        static func validations(_ validations: inout Validations) {
            validations.add("sealed", as: Sealed.self, required: true)
            validations.add("recipient", as: UUID.self, required: true)
        }
    }
    
    /// Verify that the message was recieved by the client. When the server recieves this object in a WebSocket connection the message will be deleted on the database. The client is expected to cache the data on the device in an encrypted format.
    struct RecievedConfirmation: Content, Validatable {
        
        /// The id of the message that was recieved.
        var messageId: UUID
        
        /// Conform to `Validatable`
        /// - Parameter validations: The validations to validate.
        static func validations(_ validations: inout Validations) {
            validations.add("messageId", as: UUID.self, required: true)
        }
    }
    
    /// The response included in an HTTP GET response.
    struct GetResponse: Content {
        
        /// The id for the database.
        var id: UUID
        
        /// The sealed content of the message.
        var text: Sealed
        
        /// The chat that this message was sent to.
        var chat: Chat.MessageResponse
        
        /// The participant that sent this message.
        var sender: Participant.GetResponse
        
        /// The recipient of this message.
        var recipient: Participant.GetResponse
        
        /// The timestamp that the message was created.
        var created: Date?
        
        /// The timestamp that the message was last updated.
        var updated: Date?
    }
    
    /// The sealed content of a message.
    struct Sealed: Codable {
        
        /// The ephemeral public key portion of the encrypted message.
        var ephemeralPublicKeyData: Data
        
        /// The ciphertext portion of the encrypted message.
        var ciphertext: Data
        
        /// The signature portion of the encrypted message.
        var signature: Data
        
        /// Initialize some new sealed content.
        /// - Parameters:
        ///   - ephemeralPublicKeyData: The ephemeral public key portion of the encrypted message.
        ///   - ciphertext: The ciphertext portion of the encrypted message.
        ///   - signature: The signature portion of the encrypted message.
        internal init(ephemeralPublicKeyData: Data, ciphertext: Data, signature: Data) {
            self.ephemeralPublicKeyData = ephemeralPublicKeyData
            self.ciphertext = ciphertext
            self.signature = signature
        }
    }
}
