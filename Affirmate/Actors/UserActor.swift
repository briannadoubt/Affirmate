//
//  UserActor.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import SwiftUI
import Alamofire

actor UserActor {
    
    private let http = HTTPActor()
    
    func me() async throws -> User {
        try await http.requestDecodable(Request.me, to: User.self)
    }
    
    func find(username: String?) async throws -> [User.Public] {
        try await http.requestDecodable(Request.find(username: username), to: [User.Public].self)
    }
}

extension UserActor {
    
    enum Request: URLRequestConvertible {
        
        case me
        case find(username: String?)
        
        var url: URL { Constants.baseURL.appending(component: "users") }
        var meUrl: URL { Constants.baseURL.appending(component: "me") }
        
        var uri: URLConvertible? {
            switch self {
            case .me:
                return meUrl
            case .find(let username):
                var queryItems: [URLQueryItem] = []
                if let username {
                    queryItems.append(URLQueryItem(name: "username", value: username))
                }
                return url.appending(component: "find").appending(queryItems: queryItems)
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
