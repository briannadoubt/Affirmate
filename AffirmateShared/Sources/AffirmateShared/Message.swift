//
//  Message.swift
//  AffirmateShared
//
//  Created by Bri on 11/21/22.
//

import Foundation

/// Create a new message
public struct MessageCreate: Codable {
    /// The sealed content of the message.
    public var sealed: MessageSealed
    /// The id of the recipient participant of the message.
    public var recipient: UUID
    
    /// Create a new message
    /// - Parameters:
    ///   - sealed: The sealed content of the message.
    ///   - recipient: The id of the recipient participant of the message.
    public init(sealed: MessageSealed, recipient: UUID) {
        self.sealed = sealed
        self.recipient = recipient
    }
}

/// The response included in an HTTP GET response.
public struct MessageResponse: Codable {
    /// The id for the database.
    public var id: UUID
    /// The sealed content of the message.
    public var text: MessageSealed
    /// The chat that this message was sent to.
    public var chat: ChatMessageResponse
    /// The participant that sent this message.
    public var sender: ParticipantResponse
    /// The recipient of this message.
    public var recipient: ParticipantResponse
    /// The timestamp that the message was created.
    public var created: Date?
    /// The timestamp that the message was last updated.
    public var updated: Date?
    
    /// The response included in an HTTP GET response.
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - text: The sealed content of the message.
    ///   - chat: The chat that this message was sent to.
    ///   - sender: The participant that sent this message.
    ///   - recipient: The recipient of this message.
    ///   - created: The timestamp that the message was created.
    ///   - updated: The timestamp that the message was last updated.
    public init(id: UUID, text: MessageSealed, chat: ChatMessageResponse, sender: ParticipantResponse, recipient: ParticipantResponse, created: Date? = nil, updated: Date? = nil) {
        self.id = id
        self.text = text
        self.chat = chat
        self.sender = sender
        self.recipient = recipient
        self.created = created
        self.updated = updated
    }
}

/// The sealed content of a message.
public struct MessageSealed: Codable {
    /// The ephemeral public key portion of the encrypted message.
    public var ephemeralPublicKeyData: Data
    /// The ciphertext portion of the encrypted message.
    public var ciphertext: Data
    /// The signature portion of the encrypted message.
    public var signature: Data
    
    /// The sealed content of a message.
    /// - Parameters:
    ///   - ephemeralPublicKeyData: The ephemeral public key portion of the encrypted message.
    ///   - ciphertext: The ciphertext portion of the encrypted message.
    ///   - signature: The signature portion of the encrypted message.
    public init(ephemeralPublicKeyData: Data, ciphertext: Data, signature: Data) {
        self.ephemeralPublicKeyData = ephemeralPublicKeyData
        self.ciphertext = ciphertext
        self.signature = signature
    }
}

/// Verify that the message was received by the client. When the server receives this object in a WebSocket connection the message will be deleted on the database. The client is expected to cache the data on the device in an encrypted format.
public struct MessageReceivedConfirmation: Codable {
    /// The id of the message that was received.
    public var messageId: UUID

    /// Verify that the message was received by the client. When the server receives this object in a WebSocket connection the message will be deleted on the database. The client is expected to cache the data on the device in an encrypted format.
    /// - Parameter messageId: The id of the message that was received.
    public init(messageId: UUID) {
        self.messageId = messageId
    }
}
