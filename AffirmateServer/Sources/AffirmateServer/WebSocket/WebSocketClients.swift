//
//  WebSocketClients.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import Vapor

actor WebSocketClients {
    var eventLoop: EventLoop
    var storage: [UUID: WebSocketClient]

    var active: [WebSocketClient] {
        storage.values.filter { !$0.socket.isClosed }
    }

    init(eventLoop: EventLoop, clients: [UUID: WebSocketClient] = [:]) {
        self.eventLoop = eventLoop
        storage = clients
    }

    func add(_ client: WebSocketClient) {
        storage[client.id] = client
    }

    func remove(_ client: WebSocketClient) {
        storage[client.id] = nil
    }

    func getClient(with id: UUID) -> WebSocketClient? {
        storage[id]
    }

    deinit {
        let futures = self.storage.values.map { $0.socket.close() }
        try! self.eventLoop.flatten(futures).wait()
    }
}
