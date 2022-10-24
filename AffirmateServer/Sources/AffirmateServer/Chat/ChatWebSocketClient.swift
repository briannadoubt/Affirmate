//
//  ChatWebSocketClient.swift
//  AffirmateServer
//
//  Created by Bri on 10/17/22.
//

import Vapor

open class ChatWebSocketClient: WebSocketClient {
    
    /// The id referencing this client.
    open var id: UUID
    
    /// The id referencing a `Chat` in the database.
    open var chatId: UUID
    
    /// The current WebSocket connection.
    open var socket: WebSocket
    
    /// Create a new client.
    /// - Parameters:
    ///   - id: The id referencing this client
    ///   - chatId: The id referencing a `Chat` in the database.
    ///   - socket: The current WebSocket connection.
    required public init(id: UUID, chatId: UUID, socket: WebSocket) {
        self.id = id
        self.chatId = chatId
        self.socket = socket
    }
}
