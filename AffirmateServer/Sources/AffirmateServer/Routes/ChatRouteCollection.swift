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
        let tokenProtected = routes.grouped(UserToken.authenticator())
        // MARK: - GET "/chat": Returns all authorized chats based on the user token session.
        let chat = tokenProtected.grouped("chat")
        chat.get { request async throws -> [Chat.GetResponse] in
            guard let currentUserId = try request.auth.require(User.self).id else {
                throw Abort(.forbidden)
            }
            let database = request.db
            var chatGetResponses: [Chat.GetResponse] = []
            for chat in try await getChats(for: currentUserId, on: database) {
                guard let chatId = chat.id else { continue }
                let getResponse = try await Chat.GetResponse(
                    chat: chat,
                    participants: getParticipants(for: chatId, on: request.db),
                    messages: getMessages(for: chatId, on: request.db)
                )
                chatGetResponses.append(getResponse)
            }
            return chatGetResponses
        }
        // MARK: - Get "/chat/:chatId": Returns a ChatGetResponse from a given chatId
        let specificChat = chat.grouped(":chatId")
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
                chat: chat,
                participants: chatParticipants,
                messages: getMessages(for: chatId, on: database)
            )
        }
        // MARK: - POST "/chat/:chatId/messages": Creates a new message for a given chat.
        let messages = specificChat.grouped("messages")
        messages.post { request async throws -> Message in
            try Message.Create.validate(content: request)
            let create = try request.content.decode(Message.Create.self)
            // TODO: Check message content (`create.text`) for configured blocking settings, etc.
            guard
                let chatIdString = request.parameters.get("chatId"),
                let chatId = UUID(uuidString: chatIdString) else {
                throw Abort(.badRequest)
            }
            guard let currentUserId = try request.auth.require(User.self).id else {
                throw Abort(.unauthorized)
            }
            guard
                let chat = try await Chat.find(chatId, on: request.db),
                let sender = try await User.find(currentUserId, on: request.db)
            else {
                throw Abort(.badRequest)
            }
            return Message(
                text: create.text,
                chat: chat,
                sender: sender
            )
        }
    }
}

extension ChatRouteCollection {
    private func getChats(for currentUserId: UUID, on database: Database) async throws -> [Chat] {
        try await Chat.query(on: database)
            .join(ChatParticipant.self, on: \ChatParticipant.$chat.$id == \Chat.$id)
            .filter(ChatParticipant.self, \.$user.$id, .equal, currentUserId)
            .all()
    }
    private func getParticipants(for chatId: UUID, on database: Database) async throws -> [ChatParticipant] {
        try await ChatParticipant.query(on: database)
            .filter(ChatParticipant.self, \.$chat.$id, .equal, chatId)
            .all()
    }
    private func getMessages(for chatId: UUID, on database: Database) async throws -> [Message] {
        try await Message.query(on: database)
            .filter(Message.self, \.$chat.$id, .equal, chatId)
            .all()
    }
}
