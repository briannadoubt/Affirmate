//
//  SessionToken.swift
//  AffirmateServer
//
//  Created by Bri on 8/17/22.
//

import Fluent
import Vapor

/// The token of a user of Affirmate's session.
final class SessionToken: Model, Content {
    
    /// The name of the table on the database.
    static let schema = "session_tokens"

    /// The id for the database.
    @ID(key: .id) var id: UUID?
    
    /// The session key data.
    @Field(key: "value") var value: String
    
    /// The user who owns this session.
    @Parent(key: "user_id") var user: User

    /// The moment when this token expires.
    @OptionalField(key: "expires_at") var expiresAt: Date?
    
    /// Conform to `Model`.
    init() { }
    
    /// Initialize a new `SessionToken` for the database
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - value: The session key data.
    ///   - userID: The user who owns this session.
    ///   - expiresAt: The timestamp when this session becomes invalid.
    init(id: UUID? = nil, value: String, userID: User.IDValue, expiresAt: Date? = nil) {
        self.id = id
        self.value = value
        self.$user.id = userID
        self.expiresAt = expiresAt
    }
    
    /// Handle asyncronous database migration; creating and destroying the `SessionToken` table.
    struct Migration: AsyncMigration {
        var name: String { "SessionTokenMigration" }

        /// Outlines the `session_tokens` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(SessionToken.schema)
                .id()
                .field("value", .string, .required)
                .field("user_id", .uuid, .required, .references(User.schema, .id))
                .unique(on: "value")
                .create()
        }

        /// Destroys the `session_tokens` table
        func revert(on database: Database) async throws {
            try await database.schema(SessionToken.schema).delete()
        }
    }

    /// Adds expiration metadata to existing session tokens.
    struct ExpiryMigration: AsyncMigration {
        var name: String { "SessionTokenExpiryMigration" }

        func prepare(on database: Database) async throws {
            try await database.schema(SessionToken.schema)
                .field("expires_at", .datetime)
                .update()

            let expiration = Date().addingTimeInterval(SessionToken.defaultExpirationInterval)
            try await SessionToken.query(on: database)
                .set(\.$expiresAt, to: Optional(expiration))
                .update()
        }

        func revert(on database: Database) async throws {
            try await database.schema(SessionToken.schema)
                .deleteField("expires_at")
        }
    }
}

extension SessionToken: ModelTokenAuthenticatable {

    /// Reference the value of the token
    static let valueKey = \SessionToken.$value

    /// Reference the user who owns the token
    static let userKey = \SessionToken.$user

    /// Assert whether the token is still valid.
    var isValid: Bool {
        guard let expiresAt else { return false }
        return expiresAt > Date()
    }

    /// The default lifetime for newly created session tokens.
    static let defaultExpirationInterval: TimeInterval = 60 * 60 * 24
}

extension SessionToken {

    /// Middleware that enforces token expiration and prunes expired tokens.
    struct ExpirationMiddleware: AsyncMiddleware {
        func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
            guard let token = request.auth.get(SessionToken.self) else {
                return try await next.respond(to: request)
            }

            guard token.isValid else {
                try await token.delete(on: request.db)
                request.auth.logout(SessionToken.self)
                throw Abort(.unauthorized)
            }

            return try await next.respond(to: request)
        }
    }

    /// Provide middleware that should run after authentication to validate expiration.
    static func expirationMiddleware() -> ExpirationMiddleware {
        ExpirationMiddleware()
    }
}
