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
    
    enum Keys {
        static let id = "id"
        static let firstName = "first_name"
        static let lastName = "last_name"
        static let username = "username"
        static let email = "email"
        static let passwordHash = "password_hash"
    }
    
    @ID(key: FieldKey.id) var id: UUID?
    @Field(key: Keys.firstName.fieldKey) var firstName: String
    @Field(key: Keys.lastName.fieldKey) var lastName: String
    @Field(key: Keys.username.fieldKey) var username: String
    @Field(key: Keys.email.fieldKey) var email: String
    @Field(key: Keys.passwordHash.fieldKey) var passwordHash: String
    
    init() { }
    
    init(id: UUID? = nil, firstName: String, lastName: String, username: String, email: String, passwordHash: String) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
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
                .field(User.Keys.firstName.fieldKey, .string)
                .field(User.Keys.lastName.fieldKey, .string)
                .field(User.Keys.email.fieldKey, .string, .required)
                .field(User.Keys.username.fieldKey, .string)
                .field(User.Keys.passwordHash.fieldKey, .string, .required)
                .unique(on: User.Keys.email.fieldKey)
                .unique(on: User.Keys.username.fieldKey)
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
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

extension User {
    /// The post parameter used to create a new user
    struct Create: Content {
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
    }
}

extension User.Create: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("first_name", as: String.self, is: !.empty)
        validations.add("last_name", as: String.self, is: !.empty)
        validations.add("username", as: String.self, is: !.empty && .alphanumeric && .count(3...64))
        validations.add("email", as: String.self, is: !.empty)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

extension User.Create: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case email
        case password
        case confirmPassword = "confirm_password"
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<User.Create.CodingKeys> = try decoder.container(keyedBy: User.Create.CodingKeys.self)
        self.firstName = try container.decode(String.self, forKey: User.Create.CodingKeys.firstName)
        self.lastName = try container.decode(String.self, forKey: User.Create.CodingKeys.lastName)
        self.username = try container.decode(String.self, forKey: User.Create.CodingKeys.username)
        self.email = try container.decode(String.self, forKey: User.Create.CodingKeys.email)
        self.password = try container.decode(String.self, forKey: User.Create.CodingKeys.password)
        self.confirmPassword = try container.decode(String.self, forKey: User.Create.CodingKeys.confirmPassword)
    }
}

extension User {
    var getResponse: GetResponse {
        GetResponse(id: id, firstName: firstName, lastName: lastName, username: username, email: email)
    }
    /// The get response for a user
    struct GetResponse: Content, Equatable, Codable {
        
        var id: UUID?
        var firstName: String
        var lastName: String
        var username: String
        var email: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case firstName = "first_name"
            case lastName = "last_name"
            case username
            case email
        }
        
        init(from decoder: Decoder) throws {
            id = try decoder.container(keyedBy: CodingKeys.self).decode(UUID?.self, forKey: .id)
            firstName = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .firstName)
            lastName = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .lastName)
            username = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .username)
            email = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .email)
        }
        
        init(id: UUID? = nil, firstName: String, lastName: String, username: String, email: String) {
            self.id = id
            self.firstName = firstName
            self.lastName = lastName
            self.username = username
            self.email = email
        }
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
