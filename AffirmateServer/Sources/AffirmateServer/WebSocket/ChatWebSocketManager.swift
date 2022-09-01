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
        if #available(iOS 15, *) {
            webSocket.onBinary { webSocket, buffer async -> () in
                print("Binary recieved")
                // MARK: Connect
                if let connectMessage = self.get(buffer, Connect.self) {
                    await self.handle(connect: connectMessage, request: request, webSocket: webSocket)
                    
                    // MARK: Message
                } else if let webSocketMessage = self.get(buffer, Message.Create.self) {
                    await self.handle(message: webSocketMessage, request: request, webSocket: webSocket)
                    
                    // MARK: Participant
                } else if let webSocketMessage = self.get(buffer, [Participant.Create].self) {
                    await self.handle(participants: webSocketMessage, request: request, webSocket: webSocket)
                    
                } else {
                    self.sendError("Recieved data in unrecognizable format", on: webSocket)
                }
            }
        }
    }
}
    
private extension ChatWebSocketManager {
    func handle(message: WebSocketMessage<Message.Create>, request: Request, webSocket: WebSocket) async {
        await handle(webSocket: webSocket) {
            // TODO: Check message content (`create.text`) for moderation or embedded content, etc.
            guard let createString = message.data.json else {
                throw Abort(.badRequest)
            }
            try Message.Create.validate(json: createString)
            if #available(iOS 15, *) {
                let newMessage = try await request.db.transaction { database in
                    let currentUser = try await self.getUser(request)
                    let chat = try await self.getChat(request, on: database)
                    let newMessage = try Message(text: message.data.text, chat: chat.requireID(), sender: currentUser.requireID())
                    try await newMessage.$chat.load(on: database)
                    try await newMessage.$sender.load(on: database)
                    try await chat.$messages.create(newMessage, on: database)
                    return newMessage
                }
            }
        }
    }
    
    func handle(participants message: WebSocketMessage<[Participant.Create]>, request: Request, webSocket: WebSocket) async {
        await handle(webSocket: webSocket) {
            let participants = message.data
            for participant in participants {
                guard let createString = participant.json else {
                    throw Abort(.badRequest)
                }
                try Participant.Create.validate(json: createString)
                let newParticipant = try await request.db.transaction { database in
                    let currentUser = try await self.getUser(request)
                    let chat = try await self.getChat(request, on: database)
                    guard let user = try await AffirmateUser.find(participant.user, on: database) else {
                        throw Abort(.notFound)
                    }
                    try await chat.$users.attach(user, method: .ifNotExists, on: database)
                    return user
                }
                try await self.broadcast(newParticipant.getResponse)
            }
        }
    }
    
    func handle(connect message: WebSocketMessage<Connect>, request: Request, webSocket: WebSocket) async {
        await handle(webSocket: webSocket) {
            let clientId = message.client
            let client = WebSocketClient(id: clientId, socket: webSocket)
            await self.clients.add(client)
            print("Added client app: \(clientId)")
            let confirmConnection = ConfirmConnection(connected: true)
            try await self.broadcast(confirmConnection)
        }
    }
    
    func handle(webSocket: WebSocket, withThrowing block: () async throws -> ()) async {
        do {
            try await block()
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
        try await chat.$users.load(on: database)
        for user in chat.users {
            user.passwordHash = "HIDDEN"
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
