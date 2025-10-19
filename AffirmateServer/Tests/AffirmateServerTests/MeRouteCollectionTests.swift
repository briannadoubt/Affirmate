import AffirmateShared
import XCTVapor
@testable import AffirmateServer

final class MeRouteCollectionTests: XCTestCase {
    func test_deleteMeDeletesCurrentUserAndRelatedRecords() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try! app.setUp()

        try await app
            .signUp()
            .login()

        let optionalSessionToken = try await SessionToken.query(on: app.db).first
        let sessionToken = try XCTUnwrap(optionalSessionToken)

        let optionalUser = try await User.query(on: app.db).first
        let user = try XCTUnwrap(optionalUser)
        let userID = try user.requireID()

        let chat = Chat(id: UUID(), name: "Account Cleanup", salt: Data("salt".utf8))
        try await chat.create(on: app.db)
        let chatID = try chat.requireID()

        let otherUser = User(
            firstName: "Other",
            lastName: "User",
            username: "other-user",
            email: "other@example.com",
            passwordHash: try Bcrypt.hash("Another123$")
        )
        try await otherUser.create(on: app.db)
        let otherUserID = try otherUser.requireID()

        let userPublicKey = PublicKey(
            signingKey: Data("sign".utf8),
            encryptionKey: Data("encrypt".utf8),
            user: userID,
            chat: chatID
        )
        try await userPublicKey.create(on: app.db)
        let userPublicKeyID = try userPublicKey.requireID()

        let otherPublicKey = PublicKey(
            signingKey: Data("other-sign".utf8),
            encryptionKey: Data("other-encrypt".utf8),
            user: otherUserID,
            chat: chatID
        )
        try await otherPublicKey.create(on: app.db)
        let otherPublicKeyID = try otherPublicKey.requireID()

        let participant = Participant(
            role: .participant,
            user: userID,
            chat: chatID,
            publicKey: userPublicKeyID
        )
        try await participant.create(on: app.db)
        let participantID = try participant.requireID()

        let otherParticipant = Participant(
            role: .participant,
            user: otherUserID,
            chat: chatID,
            publicKey: otherPublicKeyID
        )
        try await otherParticipant.create(on: app.db)
        let otherParticipantID = try otherParticipant.requireID()

        let message = Message(
            ephemeralPublicKeyData: Data("ephemeral".utf8),
            ciphertext: Data("ciphertext".utf8),
            signature: Data("signature".utf8),
            chat: chatID,
            sender: participantID,
            recipient: otherParticipantID
        )
        try await message.create(on: app.db)

        let invitationForCurrentUser = ChatInvitation(
            role: .participant,
            user: userID,
            invitedBy: otherParticipantID,
            chat: chatID
        )
        try await invitationForCurrentUser.create(on: app.db)

        let invitationFromCurrentUser = ChatInvitation(
            role: .participant,
            user: otherUserID,
            invitedBy: participantID,
            chat: chatID
        )
        try await invitationFromCurrentUser.create(on: app.db)

        try await app.test(.DELETE, "/me") { request in
            request.headers.bearerAuthorization = .init(token: sessionToken.value)
        } afterResponse: { response in
            XCTAssertEqual(response.status, .noContent)

            XCTAssertNil(try await User.find(userID, on: app.db))
            XCTAssertNotNil(try await User.find(otherUserID, on: app.db))

            let remainingTokens = try await SessionToken.query(on: app.db)
                .filter(\.$user.$id == userID)
                .all()
            XCTAssertTrue(remainingTokens.isEmpty)

            let remainingParticipants = try await Participant.query(on: app.db)
                .filter(\.$user.$id == userID)
                .all()
            XCTAssertTrue(remainingParticipants.isEmpty)

            let remainingKeys = try await PublicKey.query(on: app.db)
                .filter(\.$user.$id == userID)
                .all()
            XCTAssertTrue(remainingKeys.isEmpty)

            let remainingMessagesForSender = try await Message.query(on: app.db)
                .filter(\.$sender.$id == participantID)
                .all()
            XCTAssertTrue(remainingMessagesForSender.isEmpty)

            let remainingMessagesForRecipient = try await Message.query(on: app.db)
                .filter(\.$recipient.$id == participantID)
                .all()
            XCTAssertTrue(remainingMessagesForRecipient.isEmpty)

            let invitationsForUser = try await ChatInvitation.query(on: app.db)
                .filter(\.$user.$id == userID)
                .all()
            XCTAssertTrue(invitationsForUser.isEmpty)

            let invitationsFromUser = try await ChatInvitation.query(on: app.db)
                .filter(\.$invitedBy.$id == participantID)
                .all()
            XCTAssertTrue(invitationsFromUser.isEmpty)
        }

        app.tearDown()
    }
}
