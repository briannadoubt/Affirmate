//
//  ChatWebSocketManagerTests.swift
//  AffirmateServerTests
//
//  Created by OpenAI on 2024.
//

@testable import AffirmateServer
import XCTVapor
import XCTest

final class ChatWebSocketManagerTests: XCTestCase {

    func testDeleteMessageIfAuthorizedOnlyDeletesRecipientMessages() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()
        defer { app.tearDown() }

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

        let manager = ChatWebSocketManager(eventLoop: app.eventLoopGroup.next())

        try await manager.deleteMessageIfAuthorized(try messageForUserOne.requireID(), currentUser: userOne, chat: chat, database: app.db)

        let deletedMessage = try await Message.find(messageForUserOne.requireID(), on: app.db)
        XCTAssertNil(deletedMessage)

        let remainingMessage = try await Message.find(messageForUserTwo.requireID(), on: app.db)
        XCTAssertNotNil(remainingMessage)

        try await manager.deleteMessageIfAuthorized(try messageForUserTwo.requireID(), currentUser: userOne, chat: chat, database: app.db)

        let stillRemaining = try await Message.find(messageForUserTwo.requireID(), on: app.db)
        XCTAssertNotNil(stillRemaining)
    }
}
