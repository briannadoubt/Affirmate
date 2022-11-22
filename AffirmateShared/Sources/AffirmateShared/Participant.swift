//
//  Participant.swift
//  AffirmateShared
//
//  Created by Bri on 11/21/22.
//

import Foundation

/// The value denoting the permissions of the user.
public enum ParticipantRole: String, CaseIterable, Codable, Equatable, Identifiable {
    /// Has permissions to update and delete messages, or add new participants to the chat.
    case admin
    /// Only has permissions to send and read messages.
    case participant
    
    /// `Identifiable` conformance.
    public var id: String { rawValue }
    
    /// The title used on the UI.
    public var title: String {
        switch self {
        case .admin:
            return "Admin"
        case .participant:
            return "Participant"
        }
    }
}

/// Create a new participant for a chat.
public struct ParticipantCreate: Equatable, Hashable, Codable {
    /// The value denoting the permissions of the user.
    public var role: ParticipantRole
    /// The id of the user who operates this participant.
    public var user: UUID
    
    public init(role: ParticipantRole, user: UUID) {
        self.role = role
        self.user = user
    }
}

/// The response included in an HTTP GET response.
public struct ParticipantResponse: Identifiable, Codable, Equatable {
    /// The id for the database.
    public var id: UUID
    /// The value denoting the permissions of the user.
    public var role: ParticipantRole
    /// The user who operates this participant.
    public var user: UserParticipantResponse
    /// The chat that this participant is a part of.
    public var chat: ChatParticipantResponse
    /// The public signing key for the chat.
    public var signingKey: Data
    /// The public encryption key for the chat.
    public var encryptionKey: Data
    
    /// The response included in an HTTP GET response.
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - role: The value denoting the permissions of the user.
    ///   - user: The user who operates this participant.
    ///   - chat: The chat that this participant is a part of.
    ///   - signingKey: The public signing key for the chat.
    ///   - encryptionKey: The public encryption key for the chat.
    public init(id: UUID, role: ParticipantRole, user: UserParticipantResponse, chat: ChatParticipantResponse, signingKey: Data, encryptionKey: Data) {
        self.id = id
        self.role = role
        self.user = user
        self.chat = chat
        self.signingKey = signingKey
        self.encryptionKey = encryptionKey
    }
    
    public static func ==(_ lhs: ParticipantResponse, _ rhs: ParticipantResponse) -> Bool {
        lhs.id == rhs.id && lhs.role == rhs.role && lhs.user == rhs.user && lhs.chat == rhs.chat
    }
}

/// A draft participant, used on the client.
public struct ParticipantDraft: Codable, Equatable, Hashable {
    /// The value denoting the permissions of the user.
    public var role: ParticipantRole
    /// The user who operates this participant.
    public var user: UUID
    
    /// A draft participant, used on the client.
    /// - Parameters:
    ///   - role: The value denoting the permissions of the user.
    ///   - user: The user who operates this participant.
    public init(role: ParticipantRole, user: UUID) {
        self.role = role
        self.user = user
    }
}
