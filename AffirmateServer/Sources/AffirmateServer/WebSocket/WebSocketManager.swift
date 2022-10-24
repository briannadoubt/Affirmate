//
//  WebSocketManager.swift
//  AffirmateServer
//
//  Created by Bri on 10/17/22.
//

import Vapor

protocol WebSocketManager: Actor {
    
    /// The connected WebSocketClients Type
    associatedtype Clients = WebSocketClients
    
    /// The connected WebSocketClients
    var clients: Clients { get set }
    
    /// Create a new WebSocketManager on a given event loop.
    /// - Parameter eventLoop: The event loop that manages this objects threads.
    init(eventLoop: EventLoop)
    
    /// Connect to a given WebSocket connection via an HTTP Request
    /// - Parameters:
    ///   - request: The request that the WebSocket connection upgrade was requested. Also allows access to the database and application event loops.
    ///   - webSocket: The active WebSocket connection.
    func connect(_ request: Request, _ webSocket: WebSocket)
}
