//
//  WebSocketMessage.swift
//  AffirmateServer
//
//  Created by Bri on 8/22/22.
//

import AffirmateShared
import Vapor

extension ByteBuffer {
    func decodeWebSocketMessage<T: Codable>(_: T.Type) throws -> WebSocketMessage<T> {
        return try JSONDecoder().decode(WebSocketMessage<T>.self, from: self)
    }
}
