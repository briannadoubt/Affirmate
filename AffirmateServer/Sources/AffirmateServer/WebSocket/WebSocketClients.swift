//
//  WebSocketClients.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import Vapor

protocol WebSocketClients: Actor {
    associatedtype Client = WebSocketClient
    associatedtype Storage = [UUID: [UUID: Client]]
    var eventLoop: EventLoop { get set }
    var storage: Storage { get set }
    func active() -> Storage
}

actor ChatWebSocketClients: WebSocketClients {
    
    /// Format: `[chatId: [clientId: WebSocketClient]]`
    typealias Storage = [UUID: [UUID: ChatWebSocketClient]]
    
    var eventLoop: EventLoop
    var storage: Storage

    func active() -> Storage {
        var activeChats: Storage = Storage()
        storage.forEach { key, value in
            let activeClients = value.filter { element in
                !element.value.socket.isClosed
            }
            guard !activeClients.isEmpty else {
                return
            }
            activeChats[key] = activeClients
        }
        return activeChats
    }

    init(eventLoop: EventLoop, clients: Storage = [:]) {
        self.eventLoop = eventLoop
        storage = clients
    }

    func add(_ client: ChatWebSocketClient, chatId: UUID) throws {
        if storage[chatId] == nil {
            storage[chatId] = [:]
        }
        storage[chatId]?[client.id] = client
    }

    func remove(_ chatId: UUID, client: ChatWebSocketClient) {
        storage[chatId]?[client.id] = nil
        if let clients = storage[chatId], clients.isEmpty {
            storage[chatId] = nil
        }
    }

    func getClient(from chat: UUID, with clientId: UUID) -> ChatWebSocketClient? {
        storage[chat]?[clientId]
    }

    deinit {
        let futures = self.storage.values
            .map {
                $0.values.map {
                    $0.socket.close()
                }
            }
            .flatMap { $0 }
        do {
            try self.eventLoop.flatten(futures).wait()
        } catch {
            print("Failed to flatten WebSocket futures:", error)
            assertionFailure("Failed to flatten WebSocket futures")
        }
    }
}
