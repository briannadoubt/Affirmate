//
//  WebSocketMessage.swift
//  Affirmate
//
//  Created by Bri on 8/26/22.
//

import Foundation

struct WebSocketMessage<T: Codable>: Codable {
    let client: UUID
    let data: T
}
