//
//  SessionToken.swift
//  AffirmateServer
//
//  Created by Bri on 8/17/22.
//

import Fluent
import Vapor

final class SessionToken: Model, Content {
    static let schema = "session_tokens"

    @ID(key: .id) var id: UUID?
    @Field(key: Keys.value.fieldKey) var value: String
    @Parent(key: Keys.userId.fieldKey) var user: User

    enum Keys {
        static let id = "id"
        static let value = "value"
        static let userId = "user_id"
    }
    
    init() { }

    init(id: UUID? = nil, value: String, userID: User.IDValue) {
        self.id = id
        self.value = value
        self.$user.id = userID
    }
}

extension SessionToken {
    struct Migration: AsyncMigration {
        var name: String { "SessionTokenMigration" }

        func prepare(on database: Database) async throws {
            try await database.schema(SessionToken.schema)
                .id()
                .field(Keys.value.fieldKey, .string, .required)
                .field(Keys.userId.fieldKey, .uuid, .required, .references(User.schema, User.Keys.id.fieldKey))
                .unique(on: Keys.value.fieldKey)
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema(SessionToken.schema).delete()
        }
    }
}

extension SessionToken: ModelTokenAuthenticatable {
    typealias User = AffirmateServer.User
    
    static let valueKey = \SessionToken.$value
    static let userKey = \SessionToken.$user

    var isValid: Bool {
        true
    }
}
