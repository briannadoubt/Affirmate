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
    @Field(key: "value") var value: String
    @Parent(key: "user_id") var user: User
    
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
                .field("value", .string, .required)
                .field("user_id", .uuid, .required, .references(User.schema, FieldKey.id))
                .unique(on: "value")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema(SessionToken.schema).delete()
        }
    }
}

extension SessionToken: ModelTokenAuthenticatable {
    typealias User = AffirmateUser

    static let valueKey = \SessionToken.$value
    static let userKey = \SessionToken.$user

    var isValid: Bool {
        true
    }
}
