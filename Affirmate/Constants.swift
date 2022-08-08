//
//  Constants.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import Foundation

enum Constants {
    #if PRODUCTION
    static let baseURL = URL(string: "https://affirmate.org")
    #else
    static let baseURL = URL(string: "http://localhost:8080")
    #endif
    static var authURL: URL? {
        Constants.baseURL?.appending(component: "auth")
    }
    static let tokenKey = "org.affirmate.keys.token"
}
