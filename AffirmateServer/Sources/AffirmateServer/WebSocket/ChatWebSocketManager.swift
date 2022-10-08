//
//  ChatWebSocketManager.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import Vapor
import FluentKit

extension Encodable {
    var json: String? {
        guard let data = try? JSONEncoder().encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

actor ChatWebSocketManager {
    
    var clients: WebSocketClients
    
    init(eventLoop: EventLoop) {
        clients = WebSocketClients(eventLoop: eventLoop)
    }
    
    func connect(_ request: Request, _ webSocket: WebSocket) {
        webSocket.onBinary { webSocket, buffer async -> () in
            print("Binary recieved")
            // MARK: Connect
            if let connectMessage = self.get(buffer, Connect.self) {
                await self.handle(connect: connectMessage, request: request, webSocket: webSocket)
                
                // MARK: Message
            } else if let webSocketMessage = self.get(buffer, Message.Create.self) {
                await self.handle(chatMessage: webSocketMessage, request: request, webSocket: webSocket)
                
                // MARK: Participant
            } else if let webSocketMessage = self.get(buffer, [Participant.Create].self) {
                await self.handle(participants: webSocketMessage, request: request, webSocket: webSocket)
                
            } else {
                self.sendError("Recieved data in unrecognizable format", on: webSocket)
            }
        }
    }
}
    
private extension ChatWebSocketManager {
    func handle(chatMessage message: WebSocketMessage<Message.Create>, request: Request, webSocket: WebSocket) async {
        await handle(request: request, webSocket: webSocket) { database, currentUser, chat, currentParticipant in
            // TODO: Check message content (`create.text`) for moderation or embedded content, etc.
            guard let createString = message.data.json else {
                throw Abort(.badRequest)
            }
            try Message.Create.validate(json: createString)
            let newMessage = try Message(
                text: message.data.text,
                chat: chat.requireID(),
                sender: try currentParticipant.requireID()
            )
            try await newMessage.$chat.load(on: database)
            try await chat.$messages.create(newMessage, on: database)
            let newMessageResponse = Message.GetResponse(
                id: try newMessage.requireID(),
                text: newMessage.text,
                chat: Chat.MessageResponse(id: try chat.requireID()),
                sender: Participant.GetResponse(
                    id: try currentParticipant.requireID(),
                    role: currentParticipant.role,
                    user: AffirmateUser.ParticipantReponse(
                        id: try currentUser.requireID(),
                        username: currentUser.username
                    ),
                    chat: Chat.ParticipantResponse(id: try chat.requireID())
                )
            )
            try await self.broadcast(newMessageResponse)
        }
    }
    
    func handle(participants message: WebSocketMessage<[Participant.Create]>, request: Request, webSocket: WebSocket) async {
        await handle(request: request, webSocket: webSocket) { database, currentUser, chat, currentParticipant in
            let newParticipantCreates = message.data
                var newParticipants: [Participant] = []
                for newParticipantCreate in newParticipantCreates {
                    guard let createString = newParticipantCreate.json else {
                        throw Abort(.badRequest)
                    }
                    try Participant.Create.validate(json: createString)
                    let currentUser = try request.auth.require(AffirmateUser.self)
                    let chat = try await self.getChat(request, on: database)
                    let participants = try await chat.$participants.query(on: database).with(\.$user).all()
                    guard
                        let currentParticipant = try participants.first(where: { try $0.user.requireID() == currentUser.requireID() }),
                        currentParticipant.role == .admin
                    else {
                        throw Abort(.methodNotAllowed)
                    }
                    let newParticipant = Participant(
                        role: newParticipantCreate.role,
                        user: newParticipantCreate.user,
                        chat: try chat.requireID()
                    )
                    try await newParticipant.save(on: database)
                    newParticipants.append(newParticipant)
            }
            try await self.broadcast(newParticipants)
        }
    }
    
    func handle(connect message: WebSocketMessage<Connect>, request: Request, webSocket: WebSocket) async {
        await handle(request: request, webSocket: webSocket) { database, currentUser, chat, currentParticipant in
            let clientId = message.client
            let client = WebSocketClient(id: clientId, socket: webSocket)
            await self.clients.add(client)
            print("Added client app: \(clientId)")
            let confirmConnection = ConfirmConnection(connected: true)
            try await self.broadcast(confirmConnection)
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
    
    func get<T: Codable>(_ buffer: ByteBuffer, _ type: T.Type) -> WebSocketMessage<T>? {
        try? buffer.decodeWebSocketMessage(type.self)
    }
    
    func broadcast<T: Codable>(_ data: T) async throws {
        let connectedClients = await clients.active.compactMap { $0 as WebSocketClient }
        guard !connectedClients.isEmpty else {
            return
        }
        try connectedClients.forEach { client in
            let message = WebSocketMessage(client: client.id, data: data)
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
