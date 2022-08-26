//
//  WebSocketMessage.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import Vapor

struct WebSocketMessage<T: Codable>: Codable {
    let client: UUID
    let data: T
}

extension ByteBuffer {
    func decodeWebSocketMessage<T: Codable>(_: T.Type) throws -> WebSocketMessage<T> {
        return try JSONDecoder().decode(WebSocketMessage<T>.self, from: self)
    }
}
