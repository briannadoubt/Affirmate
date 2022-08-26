//
//  WebsocketManager.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import Vapor

actor ChatWebSocketManager {
    var clients: WebSocketClients

    init(eventLoop: EventLoop) {
        clients = WebSocketClients(eventLoop: eventLoop)
    }
    
    func connect(_ request: Request, _ webSocket: WebSocket) {
        webSocket.onText { webSocket, _ in
            webSocket.send("pong")
        }
        webSocket.onBinary { webSocket, buffer async -> () in
            print("Binary recieved")
            if let connect = try? buffer.decodeWebSocketMessage(Connect.self) {
                do {
                    let clientId = connect.client
                    let client = WebSocketClient(id: clientId, socket: webSocket)
                    await self.clients.add(client)
                    print("Added client app: \(clientId)")
                    let confirmConnection = ConfirmConnection(connected: true)
                    try await self.broadcast(confirmConnection)
                } catch {
                    self.sendError(error.localizedDescription, on: webSocket)
                }
            } else if let webSocketMessage = try? buffer.decodeWebSocketMessage(Message.Create.self) {
                do {
                    let create = webSocketMessage.data
                    // TODO: Check message content (`create.text`) for moderation or embedded content, etc.
                    let data = try JSONEncoder().encode(create)
                    guard let createString = String(data: data, encoding: .utf8) else {
                        throw Abort(.badRequest)
                    }
                    try Message.Create.validate(json: createString)
                    let newMessage = try await request.db.transaction { database in
                        let currentUser = try request.auth.require(User.self)
                        guard
                            let chatIdString = request.parameters.get("chatId"),
                            let chatId = UUID(uuidString: chatIdString),
                            let chat = try await Chat.find(chatId, on: database)
                        else {
                            throw Abort(.notFound)
                        }
                        let newMessage = try Message(text: create.text, chat: chat.requireID(), sender: currentUser.requireID())
                        try await newMessage.$chat.load(on: database)
                        try await newMessage.$sender.load(on: database)
                        try await chat.$messages.create(newMessage, on: database)
                        return newMessage
                    }
                    try await self.broadcast(newMessage)
                } catch {
                    self.sendError(error.localizedDescription, on: webSocket)
                }
            } else {
                self.sendError("Recieved data in unrecognizable format", on: webSocket)
            }
        }
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
