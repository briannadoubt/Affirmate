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
    
    /// Conform to `Model`.
    init() { }
    
    /// Initialize a new `SessionToken` for the database
    /// - Parameters:
    ///   - id: The id for the database.
    ///   - value: The session key data.
    ///   - userID: The user who owns this session.
    init(id: UUID? = nil, value: String, userID: User.IDValue) {
        self.id = id
        self.value = value
        self.$user.id = userID
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
}

extension SessionToken: ModelTokenAuthenticatable {

    /// Reference the value of the token
    static let valueKey = \SessionToken.$value
    
    /// Reference the user who owns the token
    static let userKey = \SessionToken.$user

    /// Assert whether the token is still valid.
    var isValid: Bool {
        // TODO: Session tokens should expire.
        true // Does not expire
    }
}
