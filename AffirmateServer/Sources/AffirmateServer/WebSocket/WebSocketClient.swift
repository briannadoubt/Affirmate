//
//  WebSocketClient.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import Vapor

protocol WebSocketClient {
    var id: UUID { get set }
    var chatId: UUID { get set }
    var socket: WebSocket { get set }
    init(id: UUID, chatId: UUID, socket: WebSocket)
}
