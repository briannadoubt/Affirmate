//
//  User.swift
//  AffirmateShared
//
//  Created by Bri on 11/21/22.
//

import Foundation
 
/// The post parameter used to create a new user
public struct UserCreate: Codable {
    /// The first name of the new user.
    public var firstName: String
    /// The last name of the new user.
    public var lastName: String
    /// A new unique username. Creation will fail if this field is duplicated in the database.
    public var username: String
    /// The new user's email. Must be unique. Creation will fail if this field is duplicated in the database.
    public var email: String
    /// The user's new password.
    public var password: String
    /// The user's password, confirmed.
    public var confirmPassword: String
    
    /// The post parameter used to create a new user
    /// - Parameters:
    ///   - firstName: The first name of the new user.
    ///   - lastName: The last name of the new user.
    ///   - username: A new unique username. Creation will fail if this field is duplicated in the database.
    ///   - email: The new user's email. Must be unique. Creation will fail if this field is duplicated in the database.
    ///   - password: The user's new password.
    ///   - confirmPassword: The user's password, confirmed.
    public init(firstName: String, lastName: String, username: String, email: String, password: String, confirmPassword: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
        self.password = password
        self.confirmPassword = confirmPassword
    }
}

/// The response included in an HTTP GET response.
public struct UserResponse: IdentifiableObject {
    /// The id for the database.
    public var id: UUID
    /// The user's first name.
    public var firstName: String
    /// The user's last name.
    public var lastName: String
    /// The user's username. Unique.
    public var username: String
    /// The user's email. Unique.
    public var email: String
    /// The user's currently open chat invitations.
    public var chatInvitations: [ChatInvitationResponse]
    
    /// The response included in an HTTP GET response.
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - firstName: The user's first name.
    ///   - lastName: The user's last name.
    ///   - username: The user's username. Unique.
    ///   - email: The user's email. Unique.
    ///   - chatInvitations: The user's currently open chat invitations.
    public init(id: UUID, firstName: String, lastName: String, username: String, email: String, chatInvitations: [ChatInvitationResponse]) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
        self.chatInvitations = chatInvitations
    }
}

/// Sent when a user logs in or refreshes their authentication token.
public struct UserLoginResponse: Codable {
    /// The current session token, to be securely cached on the client and included on future requests.
    public var sessionToken: SessionTokenResponse
    /// A representation of the user
    public var user: UserResponse
    
    /// Sent when a user logs in or refreshes their authentication token.
    /// - Parameters:
    ///   - SessionTokenResponse: The current session token, to be securely cached on the client and included on future requests.
    ///   - user: A representation of the user
    public init(sessionToken: SessionTokenResponse, user: UserResponse) {
        self.sessionToken = sessionToken
        self.user = user
    }
}

/// The response included in an HTTP GET response, embedded in a `Participant.GetResponse` object.
public struct UserParticipantResponse: Equatable, Codable {
    /// The id for the database.
    public var id: UUID
    /// The user's username. Unique.
    public var username: String
    
    /// The response included in an HTTP GET response, embedded in a `Participant.GetResponse` object.
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - username: The user's username. Unique.
    public init(id: UUID, username: String) {
        self.id = id
        self.username = username
    }
}

/// The public information of a user.
public struct UserPublic: IdentifiableObject {
    /// The id on the database.
    public var id: UUID
    /// The user's username. Unique.
    public var username: String
    
    /// The public information of a user.
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - username: The user's username. Unique.
    public init(id: UUID, username: String) {
        self.id = id
        self.username = username
    }
}
