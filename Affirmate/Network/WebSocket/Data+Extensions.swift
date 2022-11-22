//
//  Data+Extensions.swift
//  Affirmate
//
//  Created by Bri on 8/26/22.
//

import AffirmateShared
import Foundation

extension Data {
    /// Decode the data into a `WebSocketMessage` object.
    func decodeWebSocketMessage<T: Codable>(_: T.Type) throws -> WebSocketMessage<T> {
        return try JSONDecoder().decode(WebSocketMessage<T>.self, from: self)
    }
}
