//
//  WebSocketManager.swift
//  AffirmateServer
//
//  Created by Bri on 10/17/22.
//

import Vapor

protocol WebSocketManager: Actor {
    associatedtype Clients = WebSocketClients
    var clients: Clients { get set }
    init(eventLoop: EventLoop)
    func connect(_ request: Request, _ webSocket: WebSocket)
}
