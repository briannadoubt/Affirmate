//
//  UserActor.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import AffirmateShared
import SwiftUI

protocol UserActable: Actor {
    func me() async throws -> UserResponse
    func find(username: String?) async throws -> [UserPublic]
}

actor UserActor: UserActable {
    
    private let http = HTTPActor()
    
    func me() async throws -> UserResponse {
        try await http.requestDecodable(Request.me, to: UserResponse.self)
    }
    
    func find(username: String?) async throws -> [UserPublic] {
        try await http.requestDecodable(Request.find(username: username), to: [UserPublic].self)
    }
}

extension UserActor {
    
    enum Request: URLRequestConvertible, Sendable {
        
        case me
        case find(username: String?)
        
        #if os(macOS)
        var url: URL { Constants.baseURL.appendingPathComponent("users") }
        var meUrl: URL { Constants.baseURL.appendingPathComponent("me") }
        #else
        var url: URL { Constants.baseURL.appending(component: "users") }
        var meUrl: URL { Constants.baseURL.appending(component: "me") }
        #endif
        
        var uri: URL? {
            switch self {
            case .me:
                return meUrl
            case .find(let username):
                var queryItems: [URLQueryItem] = []
                if let username {
                    queryItems.append(URLQueryItem(name: "username", value: username))
                }
                var components = URLComponents()
                components.path = "users/find"
                components.queryItems = queryItems
                guard let findUrl = components.url(relativeTo: url) else {
                    return nil
                }
                print(findUrl)
                return findUrl
            }
        }
        
        var method: HTTPMethod {
            switch self {
            case .me, .find:
                return .get
            }
        }
        
        @MainActor
        func asURLRequest() throws -> URLRequest {
            guard let requestURL = uri else {
                throw ChatError.failedToBuildURL
            }
            var request = URLRequest(url: requestURL)
            request.httpMethod = method.rawValue
            var headers = HTTPHeaders()
            headers.addJSONDefaults()
            headers.apply(to: &request)
            switch self {
            case .me, .find:
                break
            }
            return request
        }
    }
}
