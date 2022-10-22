//
//  ChatWebSocketClients.swift
//  AffirmateServer
//
//  Created by Bri on 10/21/22.
//

import Vapor

actor ChatWebSocketClients: WebSocketClients {
    
    // TODO: Put this storage in Redis
    /// Format: `[chatId: [userId: [clientId: WebSocketClient]]]
    typealias Storage = [UUID: [UUID: [UUID: ChatWebSocketClient]]]
    
    var eventLoop: EventLoop
    var storage: Storage

    func active(chatId: UUID, userId: UUID) -> Storage {
        var activeChats: Storage = Storage()
        storage.forEach { chatId, userSessions in
            userSessions.forEach { userId, clients in
                let activeClients = clients.filter { element in
                    !element.value.socket.isClosed
                }
                guard !activeClients.isEmpty else {
                    return
                }
                if activeChats[chatId] == nil {
                    activeChats[chatId] = [:]
                }
                if activeChats[chatId]?[userId] == nil {
                    activeChats[chatId]?[userId] = [:]
                }
                activeChats[chatId]?[userId] = activeClients
            }
        }
        return activeChats
    }

    init(eventLoop: EventLoop, clients: Storage = [:]) {
        self.eventLoop = eventLoop
        storage = clients
    }

    func add(_ client: ChatWebSocketClient, chatId: UUID, userId: UUID) throws {
        if storage[chatId] == nil {
            storage[chatId] = [:]
        }
        if storage[chatId]?[userId] == nil {
            storage[chatId]?[userId] = [:]
        }
        storage[chatId]?[userId]?[client.id] = client
    }

    func remove(_ chatId: UUID, userId: UUID, client: ChatWebSocketClient) {
        storage[chatId]?[userId]?[client.id] = nil
        if let clients = storage[chatId]?[userId], clients.isEmpty {
            storage[chatId]?[userId] = nil
        }
    }

    func getClient(from chat: UUID, userId: UUID, with clientId: UUID) -> ChatWebSocketClient? {
        storage[chat]?[userId]?[clientId]
    }

    deinit {
        let futures = self.storage.values
            .map {
                $0.values.map {
                    $0.values.map {
                        $0.socket.close()
                    }
                }
            }
            .flatMap {
                $0.flatMap { $0 }
            }
        do {
            try self.eventLoop.flatten(futures).wait()
        } catch {
            print("Failed to flatten WebSocket futures:", error)
            assertionFailure("Failed to flatten WebSocket futures")
        }
    }
}
