//
//  ChatWebSocketManager.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import AffirmateShared
import Vapor
import FluentKit

actor ChatWebSocketManager: WebSocketManager {
    /// The connected WebSocketClients
    var clients: ChatWebSocketClients
    
    /// Create a new WebSocketManager on a given event loop.
    /// - Parameter eventLoop: The event loop that manages this objects threads.
    init(eventLoop: EventLoop) {
        clients = ChatWebSocketClients(eventLoop: eventLoop)
    }
    
    /// Connect to a given WebSocket connection via an HTTP Request
    /// - Parameters:
    ///   - request: The request that the WebSocket connection upgrade was requested. Also allows access to the database and application event loops.
    ///   - webSocket: The active WebSocket connection.
    func connect(_ request: Request, _ webSocket: WebSocket) {
        webSocket.onBinary { webSocket, buffer async -> () in
            do {
                // MARK: Connect
                if let connectMessage = try? self.get(buffer, Connect.self) {
                    await self.handle(connect: connectMessage, request: request, webSocket: webSocket)

                // MARK: Message
                } else if let confirmationMessage = try? self.get(buffer, MessageReceivedConfirmation.self) {
                    await self.handle(messageConfirmation: confirmationMessage, request: request, webSocket: webSocket)
                } else if let webSocketMessage = try self.get(buffer, MessageCreate.self) {
                    await self.handle(chatMessage: webSocketMessage, request: request, webSocket: webSocket)

                } else {
                    self.sendError("Received data in an unrecognized format", on: webSocket)
                }
            } catch {
                self.sendError("Decoding failed: \(error)", on: webSocket)
            }
        }
    }
}

extension ChatWebSocketManager {
    /// Handle a `WebSocketMessage<Message.Create>` from an open `WebSocket` connection.
    /// - Parameters:
    ///   - webSocketMessage: The message from the `WebSocket` connection.
    ///   - request: The originating `Request` with access to the `Database` and server `EventLoop`s.
    ///   - webSocket: The `WebSocket` connection that the message was received on.
    func handle(chatMessage webSocketMessage: WebSocketMessage<MessageCreate>, request: Request, webSocket: WebSocket) async {
        await handle(request: request, webSocket: webSocket) { database, currentUser, chat, sender in
            // Create JSON string from data for validation.
            guard let createString = webSocketMessage.data.json else {
                // Not a JSON object, abort.
                throw Abort(.badRequest)
            }
            // Validate the new message content
            try MessageCreate.validate(json: createString)
            
            // Create the new message.
            let messageId = UUID()
            let newMessage = Message(id: messageId, ephemeralPublicKeyData: webSocketMessage.data.sealed.ephemeralPublicKeyData, ciphertext: webSocketMessage.data.sealed.ciphertext, signature: webSocketMessage.data.sealed.signature, chat: try chat.requireID(), sender: try sender.requireID(), recipient: webSocketMessage.data.recipient)
            
            try await newMessage.$recipient.load(on: database)
            
            // Find the recipient
            guard
                let recipient = try await Participant.query(on: database)
                    .filter(\.$id == webSocketMessage.data.recipient)
                    .filter(\.$chat.$id == chat.requireID())
                    .with(\.$user)
                    .with(\.$publicKey)
                    .first()
            else {
                // No recipient found, abort.
                throw Abort(.notFound)
            }
            
            let connectedClientsForChat = await self.clients.getConnectedClients(for: try chat.requireID())
            
            // If there are no connected clients for this chat/recipient, cache the encrypted message on the database until it is retrieved.
            if try !connectedClientsForChat.contains(where: { try $1.userId == recipient.user.requireID() }) {
                // Save the message to the chat
                try await chat.$messages.create(newMessage, on: database)
                return
            }
            
            // Create the response
            let newMessageResponse = try self.createChatMessageResponse(messageId: messageId, webSocketMessage: webSocketMessage, currentUser: currentUser, chat: chat, newMessage: newMessage, sender: sender, recipient: recipient)
            
            // Broadcast to identified connected clients.
            try await self.broadcast(message: newMessageResponse, to: Array(connectedClientsForChat.values), database: database)
        }
    }

    func handle(messageConfirmation webSocketMessage: WebSocketMessage<MessageReceivedConfirmation>, request: Request, webSocket: WebSocket) async {
        await handle(request: request, webSocket: webSocket) { database, currentUser, chat, _ in
            try await deleteMessageIfAuthorized(webSocketMessage.data.messageId, currentUser: currentUser, chat: chat, database: database)
        }
    }

    func deleteMessageIfAuthorized(_ messageId: UUID, currentUser: User, chat: Chat, database: Database) async throws {
        guard let message = try await Message.find(messageId, on: database) else {
            return
        }

        guard message.$chat.id == chat.id else {
            return
        }

        try await message.$recipient.load(on: database)
        try await message.recipient.$user.load(on: database)

        guard try message.recipient.user.requireID() == currentUser.requireID() else {
            return
        }

        try await message.delete(on: database)
    }
    
    /// Handle a `Connect` object, registering the client to `self.storage`.
    /// - Parameters:
    ///   - webSocketMessage: The message from the `WebSocket` connection.
    ///   - request: The originating `Request` with access to the `Database` and server `EventLoop`s.
    ///   - webSocket: The `WebSocket` connection that the message was received on.
    func handle(connect webSocketMessage: WebSocketMessage<Connect>, request: Request, webSocket: WebSocket) async {
        await handle(request: request, webSocket: webSocket) { database, currentUser, chat, sender in
            let client = ChatWebSocketClient(id: webSocketMessage.client, userId: try currentUser.requireID(), chatId: webSocketMessage.data.chatId, socket: webSocket)
            try await self.clients.add(client)
            print("Added client app: \(webSocketMessage.client)")
            let confirmConnection = ConfirmConnection(connected: true)
            try await self.broadcast(confirmConnection, to: try currentUser.requireID(), on: webSocketMessage.data.chatId)
        }
    }
    
    /// Handle a generic `WebSocket` connection request and attach a series of objects relevant to the `Chat` to a callback.
    /// - Parameters:
    ///   - request: The originating `Request`.
    ///   - webSocket: The new `WebSocket` connection.
    ///   - block: The handler called when a message is received over the active `WebSocket` connection.
    func handle(request: Request, webSocket: WebSocket, withThrowing block: @escaping (_ database: Database, _ currentUser: User, _ chat: Chat, _ sender: Participant) async throws -> ()) async {
        do {
            try await request.db.transaction { database in
                let currentUser = try await self.getUser(request)
                let chat = try await self.getChat(request, on: database)
                guard let sender = try await chat.$participants
                    .query(on: database)
                    .filter(try \.$user.$id == currentUser.requireID())
                    .limit(1)
                    .with(\.$user)
                    .with(\.$publicKey)
                    .first()
                else {
                    throw Abort(.methodNotAllowed, reason: "You are not a part of this chat.")
                }
                try await block(database, currentUser, chat, sender)
            }
        } catch {
            self.sendError(error.localizedDescription, on: webSocket)
        }
    }
    
    /// Create a `GetRequest` for a `Message`.
    /// - Parameters:
    ///   - messageId: The id of the new message.
    ///   - webSocketMessage: The message from the WebSocket connection.
    ///   - currentUser: The currently signed in user.
    ///   - chat: The chat that the new message was received from.
    ///   - newMessage: The new `Message` instance, recently saved to the database.
    ///   - currentParticipant: The participant sending the message.
    ///   - recipientParticipant: The participant receiving the message.
    /// - Returns: A response object representing a new chat message.
    func createChatMessageResponse(messageId: UUID, webSocketMessage: WebSocketMessage<MessageCreate>, currentUser: User, chat: Chat, newMessage: Message, sender: Participant, recipient: Participant) throws -> MessageResponse {
        MessageResponse(
            id: messageId,
            text: MessageSealed(
                ephemeralPublicKeyData: newMessage.ephemeralPublicKeyData,
                ciphertext: webSocketMessage.data.sealed.ciphertext,
                signature: webSocketMessage.data.sealed.signature
            ),
            chat: ChatMessageResponse(id: try chat.requireID()),
            sender: ParticipantResponse(
                id: try sender.requireID(),
                role: sender.role,
                user: UserParticipantResponse(
                    id: try currentUser.requireID(),
                    username: currentUser.username
                ),
                chat: ChatParticipantResponse(id: try chat.requireID()),
                signingKey: sender.publicKey.signingKey,
                encryptionKey: sender.publicKey.encryptionKey
            ),
            recipient: ParticipantResponse(
                id: try newMessage.recipient.requireID(),
                role: recipient.role,
                user: UserParticipantResponse(
                    id: try recipient.user.requireID(),
                    username: recipient.user.username
                ),
                chat: ChatParticipantResponse(id: try chat.requireID()),
                signingKey: recipient.publicKey.signingKey,
                encryptionKey: recipient.publicKey.encryptionKey
            ),
            created: newMessage.created,
            updated: newMessage.updated
        )
    }
    
    /// Load the chat referenced in the URL path for `chats/<UUID>`
    /// - Parameters:
    ///   - request: The originating request with a chatId in the path.
    ///   - database: The database associated to the request. This database is referenced from an active transaction.
    /// - Returns: A chat found on the database.
    func getChat(_ request: Request, on database: Database) async throws -> Chat {
        guard
            let chatIdString = request.parameters.get("chatId"),
            let chatId = UUID(uuidString: chatIdString)
        else {
            throw Abort(.badRequest)
        }
        let chat = try await Chat.query(on: database)
            .filter(\.$id == chatId)
            .limit(1)
            .with(\.$participants) {
                $0.with(\.$user)
            }
            .with(\.$messages) {
                $0.with(\.$sender)
            }
            .first()
        guard let chat = chat else {
            throw Abort(.notFound)
        }
        return chat
    }
    
    /// Get the currently authenticated user from the given request.
    /// - Parameter request: The authenticated request.
    /// - Returns: The currently authenticated user. Throws if user is not logged in.
    func getUser(_ request: Request) throws -> User {
        try request.auth.require(User.self)	
    }
    
    /// Decode a `ByteBuffer` into a `WebSocketMessage` object.
    /// - Parameters:
    ///   - buffer: The buffer to decode, received from the WebSocket connection.
    ///   - type: The type to decode the data into.
    /// - Returns: The decoded WebSocketMessage with an embedded, decoded type.
    func get<T: Codable>(_ buffer: ByteBuffer, _ type: T.Type) throws -> WebSocketMessage<T>? {
        try buffer.decodeWebSocketMessage(type.self)
    }
    
//    /// Flatten all connected and active clients into an array for easy sending.
//    /// - Parameters:
//    ///   - userId: The userId used to look up the client.
//    ///   - chatId: The chatId used to look up the client.
//    /// - Returns: An array of active and connected clients.
//    func connectedClients(userId: UUID, chatId: UUID) async -> [ChatWebSocketClient] {
//        let activeClients = await clients.active()
//        return connectedClients
//    }
    
    /// Broadcast a new chat message to the active/connected clients.
    /// - Parameters:
    ///   - message: The message to send.
    ///   - userId: Used to reference the client.
    ///   - chatId: Used to reference the client.
    ///   - database: The `Database` attached to the originating `Request`.
    func broadcast(message: MessageResponse, to clients: [ChatWebSocketClient], database: Database) async throws {
        if clients.isEmpty {
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        for client in clients {
            let webSocketMessage = WebSocketMessage(client: client.id, data: message)
            let data = try encoder.encode(webSocketMessage)
            try await client.socket.send(raw: data, opcode: .binary)
        }
    }
    
    /// Broadcast a `Codable` object to the relevant connected and active clients.
    /// - Parameters:
    ///   - data: A `Codable` object.
    ///   - userId: The userId used to reference the client.
    ///   - chatId: The chatId used to reference the message.
    func broadcast<T: Codable>(_ data: T, to userId: UUID, on chatId: UUID) async throws {
        let connectedClients = await self.clients.active()
        guard !connectedClients.isEmpty else {
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try connectedClients.forEach { id, client in
            let webSocketMessage = WebSocketMessage(client: id, data: data)
            let encodedData = try encoder.encode(webSocketMessage)
            client.socket.send(raw: encodedData, opcode: .binary)
        }
    }
    
    /// Send an error to the current WebSocket connection.
    /// - Parameters:
    ///   - error: The description of the error
    ///   - webSocket: The current WebSocket connection
    func sendError(_ errorDescription: String, on webSocket: WebSocket) {
        guard let data = try? JSONEncoder().encode(WebSocketError(error: errorDescription)) else {
            webSocket.send("Failed to encode error: \(errorDescription)")
            return
        }
        webSocket.send(raw: data, opcode: .binary)
    }
}
