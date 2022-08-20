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
    
    init() { }
    
    init(id: UUID? = nil, role: Participant.Role, user: User.IDValue, chat: User.IDValue) {
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
    struct Create: Content, Validatable {
        var role: Role
        var userId: UUID
        
        static func validations(_ validations: inout Validations) {
            validations.add("role", as: String.self, is: !.empty)
            validations.add("user_id", as: UUID.self)
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

extension Participant {
    var getResponse: GetResponse {
        get throws {
            try GetResponse(role: role, user: user.getResponse, chat: chat.participantResponse)
        }
    }
    struct GetResponse: Content {
        var role: Role
        var user: User.GetResponse
        var chat: Chat.ParticipantResponse?
    }
}

extension Collection where Element == Participant {
    var getResponse: [Participant.GetResponse] {
        get throws {
            try map { try $0.getResponse }
        }
    }
}
