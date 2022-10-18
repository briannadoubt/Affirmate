//
//  WebSocketMessage.swift
//  Affirmate
//
//  Created by Bri on 8/26/22.
//

import Foundation

/// A message identifying which clent the message was intended for, and a codable object.
struct WebSocketMessage<T: Codable>: Codable {
    /// The client that the message was intended for.
    let client: UUID
    /// The data of the message.
    let data: T
}
