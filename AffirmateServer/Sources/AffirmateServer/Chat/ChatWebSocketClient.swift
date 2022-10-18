//
//  ChatWebSocketClient.swift
//  AffirmateServer
//
//  Created by Bri on 10/17/22.
//

import Vapor

open class ChatWebSocketClient: WebSocketClient {
    
    open var id: UUID
    open var chatId: UUID
    open var socket: WebSocket

    required public init(id: UUID, chatId: UUID, socket: WebSocket) {
        self.id = id
        self.chatId = chatId
        self.socket = socket
    }
}
