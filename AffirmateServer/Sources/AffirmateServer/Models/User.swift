//
//  User.swift
//  AffirmateServer
//
//  Created by Bri on 7/3/22.
//

import Fluent
import Vapor

extension String {
    var fieldKey: FieldKey { FieldKey(stringLiteral: self) }
    var validationKey: ValidationKey { ValidationKey(stringLiteral: self) }
}

final class User: Model, Content, Codable {
    
    static let schema = "users"
    
    @ID(key: FieldKey.id) var id: UUID?
    @Field(key: "first_name") var firstName: String
    @Field(key: "last_name") var lastName: String
    @Field(key: "username") var username: String
    @Field(key: "email") var email: String
    @Field(key: "password_hash") var passwordHash: String
    @OptionalField(key: "apns_id") var apnsId: Data?
    
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

extension User {
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
                .unique(on: "email")
                .unique(on: "username")
                .create()
        }
        /// Destroys the `user` table
        func revert(on database: Database) async throws {
            try await database.schema(User.schema).delete()
        }
    }
}

extension User: ModelAuthenticatable {
    static let usernameKey = \User.$username
    static let passwordHashKey = \User.$passwordHash
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: passwordHash)
    }
}

extension User {
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

extension User {
    var getResponse: GetResponse {
        get throws {
            GetResponse(id: try requireID(), firstName: firstName, lastName: lastName, username: username, email: email)
        }
    }
    
    struct LoginResponse: Content {
        var jwt: JWTToken.Response
        var user: GetResponse
    }
    
    /// The get response for a user
    struct GetResponse: Content, Equatable, Codable {
        var id: UUID
        var firstName: String
        var lastName: String
        var username: String
        var email: String
    }
}

extension User {
    func generateToken() throws -> SessionToken {
        try .init(
            value: [UInt8].random(count: 32).base64,
            userID: self.requireID()
        )
    }
}
