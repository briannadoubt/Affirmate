//
//  Chat.swift
//  AffirmateShared
//
//  Created by Bri on 11/20/22.
//

import Foundation

/// Create a new `Chat`
public struct ChatCreate: Codable {
    /// The id for the database.
    public var id: UUID
    /// The name of the chat. Optional.
    public var name: String?
    /// The participants to be invited to the chat. Do not include the current user in this parameter.
    public var participants: [ParticipantCreate]
    /// The public signing key of the current participant.
    public var signingKey: Data
    /// The public encryption key of the current participant.
    public var encryptionKey: Data
    /// The globally unique salt for encrypting and decrypting the sealed message content.
    public var salt: Data
    
    /// Create a new `Chat`
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - name: The name of the chat. Optional.
    ///   - participants: The participants to be invited to the chat. Do not include the current user in this parameter.
    ///   - signingKey: The public signing key of the current participant.
    ///   - encryptionKey: The public encryption key of the current participant.
    ///   - salt: The globally unique salt for encrypting and decrypting the sealed message content.
    public init(id: UUID, name: String?, participants: [ParticipantCreate], signingKey: Data, encryptionKey: Data, salt: Data) {
        self.id = id
        self.name = name
        self.participants = participants
        self.signingKey = signingKey
        self.encryptionKey = encryptionKey
        self.salt = salt
    }
}

/// The response included in an HTTP GET response.
public struct ChatResponse: Identifiable, Codable, Equatable {
    /// The id for the database.
    public var id: UUID
    /// The name of the chat. Optional.
    public var name: String?
    /// The messages of the chat.
    public var messages: [MessageResponse]
    /// The participants of the chat.
    public var participants: [ParticipantResponse]
    /// The globally unique salt for encrypting and decrypting the sealed message content.
    public var salt: Data
    
    /// The response included in an HTTP GET response.
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - name: The name of the chat. Optional.
    ///   - messages: The messages of the chat.
    ///   - participants: The participants of the chat.
    ///   - salt: The globally unique salt for encrypting and decrypting the sealed message content.
    public init(id: UUID, name: String?, messages: [MessageResponse], participants: [ParticipantResponse], salt: Data) {
        self.id = id
        self.name = name
        self.messages = messages
        self.participants = participants
        self.salt = salt
    }
    
    public static func == (lhs: ChatResponse, rhs: ChatResponse) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.participants == rhs.participants
    }
}

/// The response included in an HTTP GET response, embedded in a `ParticipantResponse` object.
public struct ChatParticipantResponse: Codable, Equatable {
    /// The id for the database.
    public var id: UUID
    
    /// The response included in an HTTP GET response, embedded in a `ParticipantResponse` object.
    /// - Parameter id: The id for the database.
    public init(id: UUID) {
        self.id = id
    }
}

/// The response included in an HTTP GET response, embedded in a `MessageResponse` object.
public struct ChatMessageResponse: Codable {
    /// The id for the database.
    public var id: UUID
    
    /// The response included in an HTTP GET response, embedded in a `MessageResponse` object.
    /// - Parameter id: The id for the database.
    public init(id: UUID) {
        self.id = id
    }
}
