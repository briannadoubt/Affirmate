//
//  ChatWebSocketManager.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import Vapor
import FluentKit

actor ChatWebSocketManager: WebSocketManager {
    
    var clients: ChatWebSocketClients
    
    init(eventLoop: EventLoop) {
        clients = ChatWebSocketClients(eventLoop: eventLoop)
    }
    
    func connect(_ request: Request, _ webSocket: WebSocket) {
        webSocket.onBinary { webSocket, buffer async -> () in
            do {
                // MARK: Connect
                if let connectMessage = try? self.get(buffer, Connect.self) {
                    await self.handle(connect: connectMessage, request: request, webSocket: webSocket)
                    
                    // MARK: Message
                } else if let webSocketMessage = try self.get(buffer, Message.Create.self) {
                    await self.handle(chatMessage: webSocketMessage, request: request, webSocket: webSocket)
                    
                } else {
                    self.sendError("Recieved data in an unrecognized format", on: webSocket)
                }
            } catch {
                self.sendError("Decoding failed: \(error)", on: webSocket)
            }
        }
    }
}

private extension ChatWebSocketManager {
    
    func handle(chatMessage message: WebSocketMessage<Message.Create>, request: Request, webSocket: WebSocket) async {
        await handle(request: request, webSocket: webSocket) { database, currentUser, chat, currentParticipant in
            guard let createString = message.data.json else {
                throw Abort(.badRequest)
            }
            try Message.Create.validate(json: createString)
            guard let recipientParticipant = try await Participant.find(message.data.recipient, on: database) else {
                throw Abort(.notFound)
            }
            try await recipientParticipant.$user.load(on: database)
            try await recipientParticipant.$publicKey.load(on: database)
            let newMessage = try Message(
                ephemeralPublicKeyData: message.data.sealed.ephemeralPublicKeyData,
                ciphertext: message.data.sealed.ciphertext,
                signature: message.data.sealed.signature,
                chat: chat.requireID(),
                sender: try currentParticipant.requireID(),
                recipient: message.data.recipient
            )
            try await newMessage.$chat.load(on: database)
            try await chat.$messages.create(newMessage, on: database)
            try await currentParticipant.$publicKey.load(on: database)
            let newMessageResponse = Message.GetResponse(
                id: try newMessage.requireID(),
                text: Message.Sealed(
                    ephemeralPublicKeyData: newMessage.ephemeralPublicKeyData,
                    ciphertext: message.data.sealed.ciphertext,
                    signature: message.data.sealed.signature
                ),
                chat: Chat.MessageResponse(id: try chat.requireID()),
                sender: Participant.GetResponse(
                    id: try currentParticipant.requireID(),
                    role: currentParticipant.role,
                    user: AffirmateUser.ParticipantResponse(
                        id: try currentUser.requireID(),
                        username: currentUser.username
                    ),
                    chat: Chat.ParticipantResponse(id: try chat.requireID()),
                    signingKey: currentParticipant.publicKey.signingKey,
                    encryptionKey: currentParticipant.publicKey.encryptionKey
                ),
                recipient: Participant.GetResponse(
                    id: message.data.recipient,
                    role: recipientParticipant.role,
                    user: AffirmateUser.ParticipantResponse(
                        id: try recipientParticipant.user.requireID(),
                        username: recipientParticipant.user.username
                    ),
                    chat: Chat.ParticipantResponse(id: try chat.requireID()),
                    signingKey: recipientParticipant.publicKey.signingKey,
                    encryptionKey: recipientParticipant.publicKey.encryptionKey
                ),
                created: newMessage.created,
                updated: newMessage.updated
            )
            // Broadcast to other user
            try await self.broadcast(newMessageResponse, to: try recipientParticipant.user.requireID(), on: chat.requireID())
        }
    }
    
    func handle(connect message: WebSocketMessage<Connect>, request: Request, webSocket: WebSocket) async {
        await handle(request: request, webSocket: webSocket) { database, currentUser, chat, currentParticipant in
            let clientId = message.client
            let client = ChatWebSocketClient(id: clientId, chatId: message.data.chatId, socket: webSocket)
            try await self.clients.add(client, chatId: message.data.chatId, userId: try currentUser.requireID())
            print("Added client app: \(clientId)")
            let confirmConnection = ConfirmConnection(connected: true)
            try await self.broadcast(confirmConnection, to: try currentUser.requireID(), on: message.data.chatId)
        }
    }
    
    func handle(request: Request, webSocket: WebSocket, withThrowing block: @escaping (_ database: Database, _ currentUser: AffirmateUser, _ chat: Chat, _ currentParticipant: Participant) async throws -> ()) async {
        do {
            try await request.db.transaction { database in
                let currentUser = try await self.getUser(request)
                let chat = try await self.getChat(request, on: database)
                let currentUserId = try currentUser.requireID()
                guard let currentParticipant = try await chat.$participants
                    .query(on: database)
                    .filter(\.$user.$id == currentUserId)
                    .limit(1)
                    .with(\.$user)
                    .first()
                else {
                    throw Abort(.methodNotAllowed, reason: "You are not a part of this chat.")
                }
                try await block(database, currentUser, chat, currentParticipant)
            }
        } catch {
            self.sendError(error.localizedDescription, on: webSocket)
        }
    }
    
    func getChat(_ request: Request, on database: Database) async throws -> Chat {
        guard
            let chatIdString = request.parameters.get("chatId"),
            let chatId = UUID(uuidString: chatIdString),
            let chat = try await Chat.find(chatId, on: database)
        else {
            throw Abort(.notFound)
        }
        try await chat.$participants.load(on: database)
        try await chat.$messages.load(on: database)
        for participant in chat.participants {
            try await participant.$user.load(on: database)
            participant.user.passwordHash = "HIDDEN"
        }
        for message in chat.messages {
            try await message.$sender.load(on: database)
        }
        return chat
    }
    
    func getUser(_ request: Request) throws -> AffirmateUser {
        try request.auth.require(AffirmateUser.self)	
    }
    
    func get<T: Codable>(_ buffer: ByteBuffer, _ type: T.Type) throws -> WebSocketMessage<T>? {
        try buffer.decodeWebSocketMessage(type.self)
    }
    
    func broadcast<T: Codable>(_ data: T, to userId: UUID, on chatId: UUID) async throws {
        guard
            let connectedClients = await clients.active(chatId: chatId, userId: userId)[chatId]?[userId]?.compactMap({ $0.value as ChatWebSocketClient }),
            !connectedClients.isEmpty
        else {
            return
        }
        try connectedClients.forEach { client in
            let message = WebSocketMessage(client: client.id, data: data)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try JSONEncoder().encode(message)
            client.socket.send(raw: data, opcode: .binary)
        }
    }
    
    func sendError(_ error: String, on webSocket: WebSocket) {
        guard let data = try? JSONEncoder().encode(WebSocketError(error: error)) else {
            webSocket.send("Failed to encode error: \(error)")
            return
        }
        webSocket.send(raw: data, opcode: .binary)
    }
}
