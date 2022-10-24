//
//  ChatWebSocketClients.swift
//  AffirmateServer
//
//  Created by Bri on 10/21/22.
//

import Vapor

actor ChatWebSocketClients: WebSocketClients {
    
    // TODO: Put this storage in Redis
    /// Format: `[chatId: [userId: [clientId: WebSocketClient]]]`
    typealias Storage = [UUID: [UUID: [UUID: ChatWebSocketClient]]]
    
    /// The event loop where all the realtime processes are run.
    var eventLoop: EventLoop
    
    /// Where all the realtime processes are stored.
    ///
    /// Format: `[chatId: [userId: [clientId: WebSocketClient]]]`
    var storage: Storage
    
    /// Filter storage to only the active clients.
    /// - Parameters:
    ///   - chatId: The relevant chatId, used to look up active clients.
    ///   - userId: The relevant userId, used to look up active clients.
    /// - Returns: A filtered list of active clients.
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
    
    /// Create a new set of clients with a destination event loop and an initial set of clients.
    /// - Parameters:
    ///   - eventLoop: The event loop where all the realtime processes are run.
    ///   - clients: The initial connected clients. This is usually left as a default value. Format: `[chatId: [userId: [clientId: WebSocketClient]]]`.
    init(eventLoop: EventLoop, clients: Storage = [:]) {
        self.eventLoop = eventLoop
        storage = clients
    }
    
    /// Add a client for a given chatId and userId to memory.
    /// - Parameters:
    ///   - client: The client to be stored in memory.
    ///   - chatId:The chatId to reference the client in memory.
    ///   - userId: The userId to reference the client in memory.
    func add(_ client: ChatWebSocketClient, chatId: UUID, userId: UUID) throws {
        if storage[chatId] == nil {
            storage[chatId] = [:]
        }
        if storage[chatId]?[userId] == nil {
            storage[chatId]?[userId] = [:]
        }
        storage[chatId]?[userId]?[client.id] = client
    }
    
    /// Remove a given client from from memory with a given chatId and userId.
    /// - Parameters:
    ///   - chatId: The chatId used to reference the client that is about to be removed.
    ///   - userId: The userId used to reference the client that is about to be removed.
    ///   - client: The client that is about to be removed. The id is used for reference during removal.
    func remove(_ chatId: UUID, userId: UUID, client: ChatWebSocketClient) {
        storage[chatId]?[userId]?[client.id] = nil
        if let clients = storage[chatId]?[userId], clients.isEmpty {
            storage[chatId]?[userId] = nil
        }
    }

    /// Attempt to get a client from memory.
    /// - Parameters:
    ///   - chatId: The chatId used to reference the client that is about to be removed.
    ///   - userId: The userId used to reference the client that is about to be removed.
    ///   - clientId: The clientId used to reference the client that is about to be removed.
    /// - Returns: If a client exists with the referenced values, return a `ChatWebSocketClient`, else return `nil`.
    func getClient(from chatId: UUID, userId: UUID, with clientId: UUID) -> ChatWebSocketClient? {
        storage[chatId]?[userId]?[clientId]
    }

    /// Assure that all event loop futures are closed when this object deinits.
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
