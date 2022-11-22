//
//  ChatWebSocketClients.swift
//  AffirmateServer
//
//  Created by Bri on 10/21/22.
//

import Vapor

actor ClientStorage {
    var clientId: UUID
    var client: ChatWebSocketClient
    init(clientId: UUID, client: ChatWebSocketClient) {
        self.clientId = clientId
        self.client = client
    }
}

actor UserClientsStorage {
    var userId: UUID
    var clients: [ClientStorage]
    init(userId: UUID, clients: [ClientStorage]) {
        self.userId = userId
        self.clients = clients
    }
}

actor ChatClientsStorage {
    var chatId: UUID
    var userClients: [UserClientsStorage]
    init(chatId: UUID, userClients: [UserClientsStorage]) {
        self.chatId = chatId
        self.userClients = userClients
    }
}

actor ChatWebSocketClients {
    
    /// The event loop where all the realtime processes are run.
    var eventLoop: EventLoop
    
    /// Where all the realtime processes are stored.
    var storage: [UUID: ChatWebSocketClient]
    
    /// Filter storage to only the active clients.
    /// - Parameters:
    ///   - chatId: The relevant chatId, used to look up active clients.
    ///   - userId: The relevant userId, used to look up active clients.
    /// - Returns: A filtered list of active clients.
    func active() -> [UUID: ChatWebSocketClient] {
        storage.filter({ !$0.value.socket.isClosed })
    }
    
    /// Create a new set of clients with a destination event loop and an initial set of clients.
    /// - Parameters:
    ///   - eventLoop: The event loop where all the realtime processes are run.
    ///   - clients: The initial connected clients. This is usually left as a default value. Format: `[chatId: [userId: [clientId: WebSocketClient]]]`.
    init(eventLoop: EventLoop, clients: [UUID: ChatWebSocketClient] = [:]) {
        self.eventLoop = eventLoop
        storage = clients
    }
    
    /// Add a client for a given chatId and userId to memory.
    /// - Parameters:
    ///   - client: The client to be stored in memory.
    ///   - chatId:The chatId to reference the client in memory.
    ///   - userId: The userId to reference the client in memory.
    func add(_ client: ChatWebSocketClient) throws {
        storage[client.id] = client
    }
    
    /// Remove a given client from from memory with a given chatId and userId.
    /// - Parameters:
    ///   - clientId: The client that is about to be removed. The id is used for reference during removal.
    func remove(clientId: UUID) {
        storage.removeValue(forKey: clientId)
    }

    /// Attempt to get a client from memory.
    /// - Parameters:
    ///   - chatId: The chatId used to reference the client that is about to be removed.
    ///   - userId: The userId used to reference the client that is about to be removed.
    ///   - clientId: The clientId used to reference the client that is about to be removed.
    /// - Returns: If a client exists with the referenced values, return a `ChatWebSocketClient`, else return `nil`.
    func getConnectedClients(for chatId: UUID) -> [UUID: ChatWebSocketClient] {
        active().filter({ $0.value.chatId == chatId })
    }

    /// Assure that all event loop futures are closed when this object deinits.
    deinit {
        let futures = self.storage.values
            .map {
                $0.socket.close()
            }
        do {
            try self.eventLoop.flatten(futures).wait()
        } catch {
            print("Failed to flatten WebSocket futures:", error)
            assertionFailure("Failed to flatten WebSocket futures")
        }
    }
}
