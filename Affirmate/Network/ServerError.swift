//
//  ServerError.swift
//  Affirmate
//
//  Created by Bri on 8/7/22.
//

import Foundation

struct ServerError: Decodable {
    var error: Bool
    var reason: String
}

struct WebSocketError: Codable {
    var error: String
}
