//
//  ChatRouteCollection.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor
import NIOFoundationCompat

enum ChatAction: String, CaseIterable {
    case sendMessage = "send_message"
}

struct ChatRouteCollection: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let tokenProtected = routes.grouped(SessionToken.authenticator(), SessionToken.guardMiddleware()) // Auth and guard with session token
        let chats = tokenProtected.grouped("chats")
        
        // MARK: - POST "/chats": Creates a new blank chat and adds the current user as a participant
        chats.post { request async throws -> HTTPStatus in
            try await request.db.transaction { transaction in
                let chatCreate = try request.content.decode(Chat.Create.self)
                let newChat = Chat(name: chatCreate.name)
                try await newChat.save(on: transaction)
                let user = try request.auth.require(AffirmateUser.self)
                guard let userId = user.id, let chatId = newChat.id else {
                    throw Abort(.notFound)
                }
                let newParticipant = Participant(role: .admin, user: userId, chat: chatId)
                print(newParticipant)
                try await newParticipant.save(on: transaction)
            }
            return .ok
        }
        
        // MARK: - GET "/chats": Returns all authorized chats based on the user token session.
        chats.get { request async throws -> [Chat] in
            try await request.db.transaction { database -> [Chat] in
                let currentUser = try request.auth.require(AffirmateUser.self)
                try await currentUser.$chats.load(on: database)
                let chats = currentUser.chats
                for chat in chats {
                    try await chat.$messages.load(on: database)
                    for message in chat.messages {
                        try await message.$sender.load(on: database)
                    }
                    try await chat.$users.load(on: database)
                    for user in chat.users {
                        user.passwordHash = "HIDDEN"
                    }
                }
                print(chats.json ?? "No Values")
                return currentUser.chats
            }
        }
        
        let specificChat = chats.grouped(":chatId")
        
        // MARK: - GET "/chat/:chatId/invitations"
        
        
        // MARK: - POST "/chat/:chatId/invitations"
        
        
//        // MARK: - POST "/chat/:chatId/messages": Creates a new message for a given chat.
//        let messages = specificChat.grouped("messages")
//        messages.post { request async throws -> HTTPStatus in
//            try Message.Create.validate(content: request)
//            let create = try request.content.decode(Message.Create.self)
//            // TODO: Check message content (`create.text`) for moderation or embedded content, etc.
//            let currentUser = try request.auth.require(AffirmateUser.self)
//            guard
//                let chatIdString = request.parameters.get("chatId"),
//                let chatId = UUID(uuidString: chatIdString),
//                let chat = try await Chat.find(chatId, on: request.db)
//            else {
//                throw Abort(.badRequest)
//            }
//            let message = try Message(text: create.text, chat: chat.requireID(), sender: currentUser.requireID())
//            try await chat.$messages.create(message, on: request.db)
//            try await chat.$users.load(on: request.db)
//            for apnsId in chat.users.compactMap({ $0.apnsId }) {
//                let deviceTokenString = apnsId.map { String(format: "%02.2hhx", $0) }.joined()
//                try request.apns.send(
//                    message.notification,
//                    pushType: .alert,
//                    to: deviceTokenString,
//                    with: JSONEncoder(),
//                    expiration: nil,
//                    priority: 10,
//                    collapseIdentifier: try chat.requireID().uuidString
//                )
//                .wait()
//            }
//            return .ok
//        }
        
        // MARK: - POST "/chat/:chatId/participants": Invite a new participant to the chat
//        let participants = specificChat.grouped("participants")
//        participants.post { request async throws -> HTTPStatus in
//            try Participant.Create.validate(content: request)
//            let create = try request.content.decode(Participant.Create.self)
//            try await request.db.transaction { database in
//                let currentUser = try request.auth.require(AffirmateUser.self)
//                guard
//                    let chatIdString = request.parameters.get("chatId"),
//                    let chatId = UUID(uuidString: chatIdString),
//                    let chat = try await Chat.find(chatId, on: database),
//                    let invitedUser = AffirmateUser.find(create.user, on: database)
//                else {
//                    throw Abort(.badRequest)
//                }
//                let participant = try Participant(role: create.role, user: create.user, chat: chatId)
////                try await invitedUser.
//                
//                guard try !chat.users.contains(where: { try $0.requireID() == participant.user.requireID() }) else {
//                    throw Abort(.methodNotAllowed, reason: "This person is already in the chat", suggestedFixes: ["Send a new person a chat request, or stop trying!"])
//                }
//                try await chat.$participants.create(participant, on: database)
//                return .ok
//            }
//        }
    }
}

extension ChatRouteCollection {
    private func getParticipants(for chatId: UUID, on database: Database) async throws -> [Participant] {
        try await Participant.query(on: database)
            .filter(Participant.self, \.$chat.$id, .equal, chatId)
            .all()
    }
    private func getMessages(for chatId: UUID, on database: Database) async throws -> [Message] {
        try await Message.query(on: database)
            .filter(Message.self, \.$chat.$id, .equal, chatId)
            .all()
    }
}
