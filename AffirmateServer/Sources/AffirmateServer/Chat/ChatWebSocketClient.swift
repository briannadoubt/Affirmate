//
//  ChatWebSocketClient.swift
//  AffirmateServer
//
//  Created by Bri on 10/17/22.
//

import Vapor

open class ChatWebSocketClient {
    
    /// The id referencing this client.
    open var id: UUID
    
    /// The id referencing a `User` in the database.
    open var userId: UUID
    
    /// The id referencing a `Chat` in the database.
    open var chatId: UUID
    
    /// The current WebSocket connection.
    open var socket: WebSocket
    
    /// Create a new client.
    /// - Parameters:
    ///   - id: The id referencing this client
    ///   - userId: The id referencing a `User` in the database.
    ///   - chatId: The id referencing a `Chat` in the database.
    ///   - socket: The current WebSocket connection.
    required public init(id: UUID, userId: UUID, chatId: UUID, socket: WebSocket) {
        self.id = id
        self.userId = userId
        self.chatId = chatId
        self.socket = socket
    }
}
