//
//  ChatRouteCollection.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Fluent
import Vapor

struct ChatRouteCollection: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let tokenProtected = routes.grouped(SessionToken.authenticator(), SessionToken.guardMiddleware()) // Auth and guard with session token
        let chatRoute = tokenProtected.grouped("chats")
        
        // MARK: - POST "/chats": Creates a new blank chat and adds the current user as a participant
        chatRoute.post { request async throws -> HTTPStatus in
            try await request.db.transaction { transaction in
                let chatCreate = try request.content.decode(Chat.Create.self)
                let newChat = Chat(name: chatCreate.name)
                try await newChat.save(on: transaction)
                let user = try request.auth.require(User.self)
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
        chatRoute.get { request async throws -> [Chat] in
            let currentUserId = try request.auth.require(User.self).requireID()
            let chats = try await Chat.query(on: request.db)
                .join(Participant.self, on: \Participant.$chat.$id == \Chat.$id)
                .filter(Participant.self, \Participant.$user.$id, .equal, currentUserId)
                .with(\.$messages) { message in
                    message
                        .with(\.$sender)
                }
                .with(\.$participants) { participant in
                    participant
                        .with(\.$user)
                }
                .all()
//            var getResponses: [Chat.GetResponse] = []
//            for chat in chats {
//                var participants: [Participant.GetResponse] = []
//                for participant in chat.participants {
//                    participants.append(try participant.getResponse)
//                }
//                var messages: [Message.GetResponse] = []
//                for message in chat.messages {
//                    messages.append(try message.getResponse)
//                }
//                let response = Chat.GetResponse(
//                    id: try chat.requireID(),
//                    participants: participants,
//                    messages: messages
//                )
//                getResponses.append(response)
//            }
            return chats
        }
        
        // MARK: - Get "/chat/:chatId": Returns a ChatGetResponse from a given chatId
        let specificChat = chatRoute.grouped(":chatId")
        specificChat.get { request async throws -> Chat.GetResponse in
            guard let currentUserId = try request.auth.require(User.self).id else {
                throw Abort(.unauthorized)
            }
            guard
                let chatIdString = request.parameters.get("chatId"),
                let chatId = UUID(uuidString: chatIdString) else {
                throw Abort(.badRequest)
            }
            let database = request.db
            let chatParticipants = try await getParticipants(for: chatId, on: database)
            guard
                let chat = try await Chat.find(chatId, on: database),
                !chatParticipants.isEmpty
            else {
                throw Abort(.notFound)
            }
            guard chatParticipants.contains(where: { $0.$user.id == currentUserId }) else {
                throw Abort(.forbidden)
            }
            return try await Chat.GetResponse(
                id: try chat.requireID(),
                participants: chatParticipants.getResponse,
                messages: getMessages(for: chatId, on: database).getResponse
            )
        }
        
        // MARK: - POST "/chat/:chatId/messages": Creates a new message for a given chat.
        let messages = specificChat.grouped("messages")
        messages.post { request async throws -> HTTPStatus in
            try Message.Create.validate(content: request)
            let create = try request.content.decode(Message.Create.self)
            // TODO: Check message content (`create.text`) for moderation or embedded content, etc.
            let currentUser = try request.auth.require(User.self)
            guard
                let chatIdString = request.parameters.get("chatId"),
                let chatId = UUID(uuidString: chatIdString),
                let chat = try await Chat.find(chatId, on: request.db)
            else {
                throw Abort(.badRequest)
            }
            let message = try Message(text: create.text, chat: chat.requireID(), sender: currentUser.requireID())
            try await chat.$messages.create(message, on: request.db)
            return .ok
        }
        
        // MARK: - POST "/chat/:chatId/participants": Invite a new participant to the chat
        let participants = specificChat.grouped("participants")
        participants.post { request async throws -> HTTPStatus in
            try Participant.Create.validate(content: request)
            let create = try request.content.decode(Participant.Create.self)
            let currentUser = try request.auth.require(User.self)
            guard
                let chatIdString = request.parameters.get("chatId"),
                let chatId = UUID(uuidString: chatIdString),
                let chat = try await Chat.find(chatId, on: request.db)
            else {
                throw Abort(.badRequest)
            }
            let participant = try Participant(role: create.role, user: currentUser.requireID(), chat: chat.requireID())
            try await chat.$participants.load(on: request.db)
            
            guard try !chat.participants.contains(where: { try $0.user.requireID() == participant.user.requireID() }) else {
                throw Abort(.methodNotAllowed, reason: "This person is already in the chat", suggestedFixes: ["Send a new person a chat request, or stop trying!"])
            }
            try await chat.$participants.create(participant, on: request.db)
            return .ok
        }
    }
}

extension ChatRouteCollection {
    private func getChats(for currentUserId: UUID, on database: Database) async throws -> [Chat] {
        try await Chat.query(on: database)
            .join(Participant.self, on: \Participant.$chat.$id == \Chat.$id)
            .filter(Participant.self, \.$user.$id, .equal, currentUserId)
            .all()
    }
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
