//
//  WebSocketClient.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import Vapor

protocol WebSocketClient {
    
    /// The id referencing this client.
    var id: UUID { get set }
    
    /// The id referencing a `Chat` in the database.
    var chatId: UUID { get set }
    
    /// The current WebSocket connection.
    var socket: WebSocket { get set }
    
    /// Create a new client.
    /// - Parameters:
    ///   - id: The id referencing this client
    ///   - chatId: The id referencing a `Chat` in the database.
    ///   - socket: The current WebSocket connection.
    init(id: UUID, chatId: UUID, socket: WebSocket)
}
