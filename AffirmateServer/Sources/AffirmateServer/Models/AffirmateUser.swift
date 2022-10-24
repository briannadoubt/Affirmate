//
//  AffirmateUser.swift
//  AffirmateServer
//
//  Created by Bri on 7/3/22.
//

import Fluent
import Vapor

/// A user of Affirmate. Stored in the database.
final class AffirmateUser: Model, Content {
    
    /// The name of the table on the database.
    static let schema = "users"
    
    /// The id for the database.
    @ID(key: FieldKey.id) var id: UUID?
    
    /// The user's first name.
    @Field(key: "first_name") var firstName: String
    
    /// The user's last name.
    @Field(key: "last_name") var lastName: String
    
    /// The user's username. Unique.
    @Field(key: "username") var username: String
    
    /// The user's email. Unique.
    @Field(key: "email") var email: String
    
    /// The user's password stored with a Bcrypt hash.
    @Field(key: "password_hash") var passwordHash: String
    
    /// The timestamp that the user was created.
    @Timestamp(key: "created", on: .create, format: .iso8601) var created: Date?
    
    /// The timestamp that the user was last updated.
    @Timestamp(key: "updated", on: .update, format: .iso8601) var updated: Date?
    
    /// The APNS id used to notify a user's Apple device
    @OptionalField(key: "apns_id") var apnsId: Data?
    
    /// The chats that this person is a participant of.
    @Siblings(through: Participant.self, from: \.$user, to: \.$chat) var chats: [Chat]
    
    /// The chats that this user has been invited to.
    @Siblings(through: ChatInvitation.self, from: \.$user, to: \.$chat) var chatInvitations: [Chat]
    
    /// Conform to `Model`.
    init() { }
    
    /// Initialize a new `AffirmateUser` object for the database.
    /// - Parameters:
    ///   - id: The id on the database
    ///   - firstName: The first name of the new user.
    ///   - lastName: The last name of the new user.
    ///   - username: A new unique username. Creation will fail if this field is duplicated in the database.
    ///   - email: The new user's email. Must be unique. Creation will fail if this field is duplicated in the database.
    ///   - passwordHash: The user's new password.
    ///   - apnsId: Optional: The APNS ID used to send notifications to iOS.
    init(id: UUID? = nil, firstName: String, lastName: String, username: String, email: String, passwordHash: String, apnsId: Data? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.apnsId = apnsId
    }
    
    /// Create a token for a new session
    func generateToken() throws -> SessionToken {
        try .init(
            value: [UInt8].random(count: 32).base64,
            userID: self.requireID()
        )
    }
    
    /// Calculate the `Public` object from a current instance. The instance is required to be loaded from the database before this object will resolve.
    /// - Returns: A public user representation.
    func publicResponse() throws -> Public {
        Public(id: try requireID(), username: username)
    }
    
    /// The public information of a user.
    struct Public: Content, Equatable, Codable {
        
        /// The id on the database.
        var id: UUID
        
        /// The user's username. Unique.
        var username: String
    }
    
    /// Handle asyncronous database migration; creating and destroying the "User" table.
    struct Migration: AsyncMigration {
        
        /// The name of the migrator
        var name: String { "UserMigration" }
        
        /// Outlines the `user` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(AffirmateUser.schema)
                .id()
                .field("first_name", .string)
                .field("last_name", .string)
                .field("email", .string, .required)
                .field("username", .string)
                .field("password_hash", .string, .required)
                .field("apns_id", .data)
                .field("created", .string)
                .field("updated", .string)
                .unique(on: "email", "username")
                .create()
        }
        
        /// Destroys the `user` table
        func revert(on database: Database) async throws {
            try await database.schema(AffirmateUser.schema).delete()
        }
    }
    
    /// The post parameter used to create a new user
    struct Create: Content, Validatable, Codable {
        
        /// The first name of the new user.
        var firstName: String
        
        /// The last name of the new user.
        var lastName: String
        
        /// A new unique username. Creation will fail if this field is duplicated in the database.
        var username: String
        
        /// The new user's email. Must be unique. Creation will fail if this field is duplicated in the database.
        var email: String
        
        /// The user's new password.
        var password: String
        
        /// The user's password, confirmed.
        var confirmPassword: String
        
        /// Create a new user.
        /// - Parameters:
        ///   - firstName: The first name of the new user.
        ///   - lastName: The last name of the new user.
        ///   - username: A new unique username. Creation will fail if this field is duplicated in the database.
        ///   - email: The new user's email. Must be unique. Creation will fail if this field is duplicated in the database.
        ///   - password: The user's new password.
        ///   - confirmPassword: The user's password, confirmed.
        init(firstName: String, lastName: String, username: String, email: String, password: String, confirmPassword: String) {
            self.firstName = firstName
            self.lastName = lastName
            self.username = username
            self.email = email
            self.password = password
            self.confirmPassword = confirmPassword
        }
        
        /// Conform to `Validatable`
        /// - Parameter validations: The validations to validate.
        static func validations(_ validations: inout Validations) {
            validations.add("firstName", as: String.self, is: !.empty)
            validations.add("lastName", as: String.self, is: !.empty)
            validations.add("username", as: String.self, is: !.empty && .alphanumeric && .count(3...64))
            validations.add("email", as: String.self, is: !.empty)
            validations.add("password", as: String.self, is: .count(8...))
        }
    }
    
    /// Sent when a user logs in or refreshes their authentication token.
    struct LoginResponse: Content {
        
        /// The current session token, to be securely cached on the client and included on future requests.
        var sessionToken: SessionToken
        
        /// A representation of the user
        var user: GetResponse
    }
    
    /// The response included in an HTTP GET response.
    struct GetResponse: Content, Equatable, Codable {
        
        /// The id for the database.
        var id: UUID
        
        /// The user's first name.
        var firstName: String
        
        /// The user's last name.
        var lastName: String
        
        /// The user's username. Unique.
        var username: String
        
        /// The user's email. Unique.
        var email: String
        
        /// The user's currently open chat invitations.
        var chatInvitations: [ChatInvitation.GetResponse]
    }
    
    /// The response included in an HTTP GET response, embedded in a `Participant.GetResponse` object.
    struct ParticipantResponse: Content, Equatable, Codable {
        
        /// The id for the database.
        var id: UUID
        
        /// The user's username. Unique.
        var username: String
    }
}

extension AffirmateUser: ModelAuthenticatable {
    
    /// Conform to `ModelAuthenticatable`; the key referencing the `AffirmateUser.username` value.
    static let usernameKey = \AffirmateUser.$username
    
    /// Conform to `ModelAuthenticatable`; the key referencing the `AffirmateUser.passwordHash` value.
    static let passwordHashKey = \AffirmateUser.$passwordHash
    
    /// Conform to `ModelAuthenticatable`; Verify the password is valid.
    func verify(password: String) throws -> Bool {
        // Use Bcrypt algorithm to verify the password against the password hash.
        try Bcrypt.verify(password, created: passwordHash)
    }
}
