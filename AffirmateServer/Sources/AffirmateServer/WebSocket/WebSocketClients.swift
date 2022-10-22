//
//  WebSocketClients.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import Vapor

protocol WebSocketClients: Actor {
    associatedtype Client = WebSocketClient
    /// Format: `[objectId: [userId: [clientId: WebSocketClient]]]
    associatedtype Storage = [UUID: [UUID: [UUID: Client]]]
    /// The event loop that manages the processes of the `WebSocketClient` instances.
    var eventLoop: EventLoop { get set }
    /// Where the instances of our `WebSocketClients` are stored and accessed.
    var storage: Storage { get set }
    /// Calculate the active clients for a given user and chatId
    func active(chatId: UUID, userId: UUID) -> Storage
}
