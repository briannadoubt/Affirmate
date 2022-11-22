//
//  UserActor.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import AffirmateShared
import Alamofire
import SwiftUI

protocol UserActable: Repository, Actor {
    func me() async throws -> UserResponse
    func find(username: String?) async throws -> [UserPublic]
}

actor UserActor {
    
    private let http = HTTPActor()
    
    func me() async throws -> UserResponse {
        try await http.requestDecodable(Request.me, to: UserResponse.self)
    }
    
    func find(username: String?) async throws -> [UserPublic] {
        try await http.requestDecodable(Request.find(username: username), to: [UserPublic].self)
    }
}

extension UserActor {
    
    enum Request: URLRequestConvertible {
        
        case me
        case find(username: String?)
        
        #if os(macOS)
        var url: URL { Constants.baseURL.appendingPathComponent("users") }
        var meUrl: URL { Constants.baseURL.appendingPathComponent("me") }
        #else
        var url: URL { Constants.baseURL.appending(component: "users") }
        var meUrl: URL { Constants.baseURL.appending(component: "me") }
        #endif
        
        var uri: URLConvertible? {
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
        
        var headers: HTTPHeaders {
            var headers = HTTPHeaders()
            headers.add(.defaultAcceptLanguage)
            headers.add(.defaultUserAgent)
            headers.add(.defaultAcceptEncoding)
            headers.add(.contentType("application/json"))
            headers.add(.accept("application/json"))
            return headers
        }
        
        func asURLRequest() throws -> URLRequest {
            guard let requestURL = uri else {
                throw ChatError.failedToBuildURL
            }
            let request = try URLRequest(url: requestURL, method: method, headers: headers)
            switch self {
            case .me, .find:
                break
            }
            return request
        }
    }
}
