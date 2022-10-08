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
            try await request.db.transaction { database in
                let chatCreate = try request.content.decode(Chat.Create.self)
                let newChat = Chat(name: chatCreate.name)
                try await newChat.save(on: database)
                let currentUser = try request.auth.require(AffirmateUser.self)
                var newParticipants = try chatCreate.participants.map {
                    Participant(
                        role: $0.role,
                        user: $0.user,
                        chat: try newChat.requireID()
                    )
                }
                let currentParticipant = Participant(
                    role: .admin,
                    user: try currentUser.requireID(),
                    chat: try newChat.requireID()
                )
                newParticipants.append(currentParticipant)
                print(newParticipants)
                try await newChat.$participants.create(newParticipants, on: database)
            }
            return .ok
        }
        
        // MARK: - GET "/chats": Returns all authorized chats based on the user token session.
        chats.get { request async throws -> [Chat.GetResponse] in
            try await request.db.transaction { database in
                let currentUser = try request.auth.require(AffirmateUser.self)
                let chats = try await currentUser.$chats.query(on: database)
                    .with(\.$messages) {
                        $0.with(\.$sender) {
                            $0.with(\.$user)
                        }
                    }
                    .with(\.$participants) {
                        $0.with(\.$user)
                    }
                    .all()
                return try chats.map { chat in
                    return Chat.GetResponse(
                        id: try chat.requireID(),
                        name: chat.name,
                        messages: try chat.messages.map { message in
                            Message.GetResponse(
                                id: try message.requireID(),
                                text: message.text,
                                chat: Chat.MessageResponse(id: try chat.requireID()),
                                sender: Participant.GetResponse(
                                    id: try message.sender.requireID(),
                                    role: message.sender.role,
                                    user: AffirmateUser.ParticipantReponse(
                                        id: try message.sender.user.requireID(),
                                        username: message.sender.user.username
                                    ),
                                    chat: Chat.ParticipantResponse(id: try chat.requireID())
                                )
                            )
                        },
                        participants: try chat.participants.map { participant in
                            Participant.GetResponse(
                                id: try participant.requireID(),
                                role: participant.role,
                                user: AffirmateUser.ParticipantReponse(
                                    id: try participant.user.requireID(),
                                    username: participant.user.username
                                ),
                                chat: Chat.ParticipantResponse(id: try chat.requireID())
                            )
                        }
                    )
                }
            }
        }
        
//        let specificChat = chats.grouped(":chatId")
        
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
