//
//  UserToken.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

final class UserToken: Model, Content {
    static let schema = "userToken"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "value") var value: String
    @Field(key: "expires_at") var expiresAt: Date
    @Parent(key: "user_id") var user: User
    
    init() { }
    
    init(id: UUID? = nil, value: String, userId: User.IDValue) {
        self.id = id
        self.value = value
        self.expiresAt = Date(timeIntervalSinceNow: 60 * 60 * 24) // 24 hours
        self.$user.id = userId
    }
}

extension UserToken {
    struct Migration: AsyncMigration {
        var name: String { "CreateUserToken" }
        
        func prepare(on database: Database) async throws {
            try await database.schema("user_token")
                .id()
                .field("value", .string, .required)
                .field("user_id", .uuid, .required, .references(User.schema, .id))
                .unique(on: "value")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema("user_token").delete()
        }
    }
}

extension UserToken: ModelTokenAuthenticatable {
    static let valueKey = \UserToken.$value
    static let userKey = \UserToken.$user
    var isValid: Bool {
        Date() < expiresAt
    }
}
