//
//  ChatRouteCollectionTests.swift
//

@testable import AffirmateServer
import AffirmateShared
import Vapor
import XCTVapor

final class ChatRouteCollectionTests: XCTestCase {

    func test_joinChatUsesInvitationRole() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()
        defer { app.tearDown() }

        let adminPassword = try Bcrypt.hash("AdminPass123!")
        let participantPassword = try Bcrypt.hash("ParticipantPass123!")

        let adminUser = User(
            firstName: "Admin",
            lastName: "User",
            username: "admin-user",
            email: "admin@example.com",
            passwordHash: adminPassword
        )
        try await adminUser.save(on: app.db)

        let participantUser = User(
            firstName: "Participant",
            lastName: "User",
            username: "participant-user",
            email: "participant@example.com",
            passwordHash: participantPassword
        )
        try await participantUser.save(on: app.db)

        let chat = Chat(id: UUID(), name: "Test Chat", salt: Data("chat-salt".utf8))
        try await chat.save(on: app.db)

        let adminPublicKey = PublicKey(
            signingKey: Data("admin-signing".utf8),
            encryptionKey: Data("admin-encryption".utf8),
            user: try adminUser.requireID(),
            chat: try chat.requireID()
        )
        try await adminPublicKey.save(on: app.db)

        let adminParticipant = Participant(
            role: .admin,
            user: try adminUser.requireID(),
            chat: try chat.requireID(),
            publicKey: try adminPublicKey.requireID()
        )
        try await adminParticipant.save(on: app.db)

        let invitation = ChatInvitation(
            role: .participant,
            user: try participantUser.requireID(),
            invitedBy: try adminParticipant.requireID(),
            chat: try chat.requireID()
        )
        try await invitation.save(on: app.db)

        let sessionToken = SessionToken(value: "test-session-token", userID: try participantUser.requireID())
        try await sessionToken.save(on: app.db)

        let joinConfirmation = ChatInvitationJoin(
            id: try invitation.requireID(),
            signingKey: Data("participant-signing".utf8),
            encryptionKey: Data("participant-encryption".utf8)
        )

        try await app.test(.POST, "/chats/\(try chat.requireID().uuidString)/join/") { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: sessionToken.value)
            try request.content.encode(joinConfirmation, using: JSONEncoder())
        } afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        }

        let persistedParticipant = try await Participant.query(on: app.db)
            .filter(\.$chat.$id == try chat.requireID())
            .filter(\.$user.$id == try participantUser.requireID())
            .first()

        let participant = try XCTUnwrap(persistedParticipant)
        XCTAssertEqual(participant.role, .participant)
    }
}
