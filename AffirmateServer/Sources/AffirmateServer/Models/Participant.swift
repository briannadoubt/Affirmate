//
//  Participant.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

final class Participant: Model, Content, Equatable {
    
    static func == (lhs: Participant, rhs: Participant) -> Bool {
        lhs.id == rhs.id
    }
    
    static let schema = "participant"
    
    @ID(key: FieldKey.id) var id: UUID?
    @Field(key: "role") var role: Role
    @Parent(key: "user_id") var user: AffirmateUser
    @Parent(key: "chat_id") var chat: Chat
    
    init() { }
    
    init(id: UUID? = nil, role: Participant.Role = .participant, user: AffirmateUser.IDValue, chat: AffirmateUser.IDValue) {
        self.id = id
        self.role = role
        self.$user.id = user
        self.$chat.id = chat
    }
    
    enum Role: String, CaseIterable, Codable, Hashable {
        case admin
        case participant
    }
}

extension Participant {
    struct Create: Content, Validatable, Equatable, Hashable {
        var role: Role
        var user: UUID
        static func validations(_ validations: inout Validations) {
            validations.add("role", as: String.self, is: !.empty)
            validations.add("user", as: UUID.self)
        }
    }
}

extension Participant {
    /// Handle asyncronous database migration; creating and destroying the "ChatParticipant" table.
    struct Migration: AsyncMigration {
        /// The name of the migrator
        var name: String { "ParticipantMigration" }
        /// Outlines the `chat-participants` table schema
        func prepare(on database: Database) async throws {
            try await database.schema(Participant.schema)
                .id()
                .field("role", .string, .required)
                .field("user_id", .uuid, .required, .references(AffirmateUser.schema, .id))
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .unique(on: "user_id", "chat_id")
                .create()
        }
        /// Destroys the `chat_participants` table
        func revert(on database: Database) async throws {
            try await database.schema(Participant.schema).delete()
        }
    }
}

extension Participant {
    struct GetResponse: Content {
        var id: UUID
        var role: Role
        var user: AffirmateUser.ParticipantReponse
        var chat: Chat.ParticipantResponse
    }
}
