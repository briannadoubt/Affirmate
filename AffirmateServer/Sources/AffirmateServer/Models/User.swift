//
//  User.swift
//  AffirmateServer
//
//  Created by Bri on 7/3/22.
//

import AffirmateShared
import Fluent
import Vapor

/// A user of Affirmate. Stored in the database.
final class User: Model, Content {
    
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
    
    /// Initialize a new `User` object for the database.
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
            userID: self.requireID(),
            expiresAt: Date().addingTimeInterval(SessionToken.defaultExpirationInterval)
        )
    }
    
    /// Calculate the `Public` object from a current instance. The instance is required to be loaded from the database before this object will resolve.
    /// - Returns: A public user representation.
    func publicResponse() throws -> UserPublic {
        UserPublic(id: try requireID(), username: username)
    }
    
    /// Handle asyncronous database migration; creating and destroying the "User" table.
    struct Migration: AsyncMigration {
        /// The name of the migrator
        var name: String { "UserMigration" }
        
        /// Outlines the `user` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(User.schema)
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
            try await database.schema(User.schema).delete()
        }
    }
}

extension User: ModelAuthenticatable {
    /// Conform to `ModelAuthenticatable`; the key referencing the `User.username` value.
    static let usernameKey = \User.$username
    /// Conform to `ModelAuthenticatable`; the key referencing the `User.passwordHash` value.
    static let passwordHashKey = \User.$passwordHash
    /// Conform to `ModelAuthenticatable`; Verify the password is valid.
    func verify(password: String) throws -> Bool {
        // Use Bcrypt algorithm to verify the password against the password hash.
        try Bcrypt.verify(password, created: passwordHash)
    }
}

extension UserCreate: Content, Validatable {
    /// Conform to `Validatable`
    /// - Parameter validations: The validations to validate.
    public static func validations(_ validations: inout Validations) {
        validations.add("firstName", as: String.self, is: !.empty)
        validations.add("lastName", as: String.self, is: !.empty)
        validations.add("username", as: String.self, is: !.empty && .alphanumeric && .count(3...64))
        validations.add("email", as: String.self, is: !.empty)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

extension UserResponse: Content { }
extension UserLoginResponse: Content { }
extension UserParticipantResponse: Content { }
extension UserPublic: Content { }

extension User {
    
    static func getCurrentUserResponse(_ currentUser: User, database: Database) async throws -> UserResponse {
        let chatInvitations = try await currentUser.$chatInvitations
            .query(on: database)
            .with(\.$openInvitations) {
                $0
                    .with(\.$invitedBy) {
                        $0.with(\.$publicKey)
                        $0.with(\.$user)
                    }
                    .with(\.$user)
                    .with(\.$chat) {
                        $0.with(\.$participants) {
                            $0.with(\.$user)
                        }
                    }
            }
            .all()
            .flatMap { chat in
                chat.openInvitations
            }
            .filter {
                try $0.user.requireID() == currentUser.requireID()
            }
        let getResponse = try UserResponse(
            id: currentUser.requireID(),
            firstName: currentUser.firstName,
            lastName: currentUser.lastName,
            username: currentUser.username,
            email: currentUser.email,
            chatInvitations: chatInvitations.map {
                return try ChatInvitationResponse(
                    id: $0.requireID(),
                    role: $0.role,
                    userId: $0.user.requireID(),
                    invitedBy: $0.invitedBy.requireID(),
                    invitedByUsername: $0.invitedBy.user.username,
                    chatId: $0.chat.requireID(),
                    chatName: $0.chat.name,
                    chatParticipantUsernames: $0.chat.participants.map { $0.user.username },
                    chatSalt: $0.chat.salt
                )
            }
        )
        return getResponse
    }
}
