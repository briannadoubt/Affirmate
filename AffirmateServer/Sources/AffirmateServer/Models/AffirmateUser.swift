//
//  AffirmateUser.swift
//  AffirmateServer
//
//  Created by Bri on 7/3/22.
//

import Fluent
import Vapor

final class AffirmateUser: Model, Content, Codable {
    
    static let schema = "users"
    
    @ID(key: FieldKey.id) var id: UUID?
    
    @Field(key: "first_name") var firstName: String
    @Field(key: "last_name") var lastName: String
    @Field(key: "username") var username: String
    @Field(key: "email") var email: String
    @Field(key: "password_hash") var passwordHash: String
    
    @Timestamp(key: "created", on: .create) var created: Date?
    @Timestamp(key: "updated", on: .update) var updated: Date?
    
    @OptionalField(key: "apns_id") var apnsId: Data?
    
    @Siblings(through: Participant.self, from: \.$user, to: \.$chat) var chats: [Chat]
    @Siblings(through: ChatInvitation.self, from: \.$user, to: \.$chat) var chatInvitations: [Chat]
    
    @Children(for: \.$user) var publicKeys: [PublicKey]
    
    init() { }
    
    init(id: UUID? = nil, firstName: String, lastName: String, username: String, email: String, passwordHash: String, apnsId: Data? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.apnsId = apnsId
    }
}

extension AffirmateUser {
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
                .field("created", .datetime)
                .field("updated", .datetime)
                .unique(on: "email", "username")
                .create()
        }
        /// Destroys the `user` table
        func revert(on database: Database) async throws {
            try await database.schema(AffirmateUser.schema).delete()
        }
    }
}

extension AffirmateUser: ModelAuthenticatable {
    static let usernameKey = \AffirmateUser.$username
    static let passwordHashKey = \AffirmateUser.$passwordHash
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: passwordHash)
    }
}

extension AffirmateUser {
    /// The post parameter used to create a new user
    struct Create: Content, Validatable, Codable {
        var firstName: String
        var lastName: String
        var username: String
        var email: String
        var password: String
        var confirmPassword: String
        
        init(firstName: String, lastName: String, username: String, email: String, password: String, confirmPassword: String) {
            self.firstName = firstName
            self.lastName = lastName
            self.username = username
            self.email = email
            self.password = password
            self.confirmPassword = confirmPassword
        }
        
        static func validations(_ validations: inout Validations) {
            validations.add("firstName", as: String.self, is: !.empty)
            validations.add("lastName", as: String.self, is: !.empty)
            validations.add("username", as: String.self, is: !.empty && .alphanumeric && .count(3...64))
            validations.add("email", as: String.self, is: !.empty)
            validations.add("password", as: String.self, is: .count(8...))
        }
    }
}

extension AffirmateUser {
    
    struct LoginResponse: Content {
        var sessionToken: SessionToken
        var user: GetResponse
    }
    
    /// The get response for a user
    struct GetResponse: Content, Equatable, Codable {
        var id: UUID
        var firstName: String
        var lastName: String
        var username: String
        var email: String
        var chatInvitations: [ChatInvitation.GetResponse]
    }
    
    struct ParticipantReponse: Content, Equatable, Codable {
        var id: UUID
        var username: String
    }
}

extension AffirmateUser {
    func publicResponse() throws -> Public {
        Public(id: try requireID(), username: username)
    }
    struct Public: Content, Equatable, Codable {
        var id: UUID
        var username: String
    }
}

extension AffirmateUser {
    func generateToken() throws -> SessionToken {
        try .init(
            value: [UInt8].random(count: 32).base64,
            userID: self.requireID()
        )
    }
}
