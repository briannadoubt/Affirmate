//
//  ChatRouteCollectionTests.swift
//  AffirmateServerTests
//
//  Created by OpenAI on 2024.
//

@testable import AffirmateServer
import AffirmateShared
import XCTVapor
import XCTest

final class ChatRouteCollectionTests: XCTestCase {

    func testSyncDeletesOnlyMessagesForCurrentUser() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()
        defer { app.tearDown() }

        // Create two users.
        let passwordHash = try Bcrypt.hash("Test123$")
        let userOne = User(firstName: "First", lastName: "User", username: "user1", email: "user1@example.com", passwordHash: passwordHash)
        try await userOne.save(on: app.db)
        let userTwo = User(firstName: "Second", lastName: "User", username: "user2", email: "user2@example.com", passwordHash: passwordHash)
        try await userTwo.save(on: app.db)

        let chat = Chat(id: UUID(), name: "Test Chat", salt: Data("salt".utf8))
        try await chat.save(on: app.db)

        let publicKeyOne = PublicKey(signingKey: Data("signing1".utf8), encryptionKey: Data("encryption1".utf8), user: try userOne.requireID(), chat: try chat.requireID())
        try await publicKeyOne.save(on: app.db)
        let publicKeyTwo = PublicKey(signingKey: Data("signing2".utf8), encryptionKey: Data("encryption2".utf8), user: try userTwo.requireID(), chat: try chat.requireID())
        try await publicKeyTwo.save(on: app.db)

        let participantOne = Participant(role: .admin, user: try userOne.requireID(), chat: try chat.requireID(), publicKey: try publicKeyOne.requireID())
        try await participantOne.save(on: app.db)
        let participantTwo = Participant(role: .participant, user: try userTwo.requireID(), chat: try chat.requireID(), publicKey: try publicKeyTwo.requireID())
        try await participantTwo.save(on: app.db)

        let messageForUserOne = Message(
            id: UUID(),
            ephemeralPublicKeyData: Data("e1".utf8),
            ciphertext: Data("c1".utf8),
            signature: Data("s1".utf8),
            chat: try chat.requireID(),
            sender: try participantTwo.requireID(),
            recipient: try participantOne.requireID()
        )
        try await messageForUserOne.save(on: app.db)

        let messageForUserTwo = Message(
            id: UUID(),
            ephemeralPublicKeyData: Data("e2".utf8),
            ciphertext: Data("c2".utf8),
            signature: Data("s2".utf8),
            chat: try chat.requireID(),
            sender: try participantOne.requireID(),
            recipient: try participantTwo.requireID()
        )
        try await messageForUserTwo.save(on: app.db)

        let sessionToken = try userOne.generateToken()
        try await sessionToken.save(on: app.db)

        try await app.test(.GET, "/chats") { request in
            request.headers.bearerAuthorization = BearerAuthorization(token: sessionToken.value)
        } afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            let chatResponses = try response.content.decode([ChatResponse].self)
            XCTAssertEqual(chatResponses.count, 1)
            XCTAssertEqual(chatResponses.first?.messages.count, 1)
            XCTAssertEqual(chatResponses.first?.messages.first?.id, try messageForUserOne.requireID())
        }

        let remainingMessages = try await Message.query(on: app.db).all()
        XCTAssertEqual(remainingMessages.count, 1)
        let remaining = try XCTUnwrap(remainingMessages.first)
        XCTAssertEqual(remaining.id, try messageForUserTwo.requireID())
    }
}
