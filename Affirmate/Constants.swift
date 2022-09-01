//
//  Constants.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import Foundation

enum Constants {
    #if PRODUCTION
    static let baseURL = URL(string: "https://affirmate.org")!
    static let baseSocketURL = URL(string: "wss://affirmate.org")!
    #elseif targetEnvironment(simulator)
    static let baseURL = URL(string: "http://localhost:8080")!
    static let baseSocketURL = URL(string: "ws://localhost:8080")!
    #elseif DEBUG
    static let baseURL = URL(string: "http://10.0.0.77:8080")!
    static let baseSocketURL = URL(string: "ws://10.0.0.77:8080")!
    #endif
    
    static let sessionTokenKey = "org.affirmate.keys.session"
    static let jwtKey = "org.affirmate.keys.jwt"
    static let chatClientIdKey = "org.affirmate.keys.chatClientId"
}
