//
//  Data+Extensions.swift
//  Affirmate
//
//  Created by Bri on 8/26/22.
//

import Foundation

extension Data {
    func decodeWebSocketMessage<T: Codable>(_: T.Type) throws -> WebSocketMessage<T> {
        return try JSONDecoder().decode(WebSocketMessage<T>.self, from: self)
    }
}
