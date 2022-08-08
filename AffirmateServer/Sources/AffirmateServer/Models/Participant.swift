//
//  Participant.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

final class Participant: Model, Content {
    
    static let schema = "participant"
    static let idKey = "participant_id"
    
    @ID(key: FieldKey.id) var id: UUID?
    @Field(key: "role") var role: Role
    @Parent(key: "user_id") var user: User
    @Parent(key: "chat_id") var chat: Chat
    
    enum Role: String, CaseIterable, Codable, Hashable {
        case admin
        case participant
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
                .field("role", .int, .required)
                .field("user_id", .uuid, .required, .references(User.schema, .id))
                .field("chat_id", .uuid, .required, .references(Chat.schema, .id))
                .create()
        }
        /// Destroys the `chat_participants` table
        func revert(on database: Database) async throws {
            try await database.schema(Participant.schema).delete()
        }
    }
}
