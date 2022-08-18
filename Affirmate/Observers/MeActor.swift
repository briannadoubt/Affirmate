//
//  MeActor.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import SwiftUI
import Alamofire

actor MeActor {
    private let http = HTTPActor()
    func get() async throws -> User {
        try await http.requestDecodable(Request.get, to: User.self)
    }
    enum Request: URLRequestConvertible {
        
        case get
        
        var url: URL? { Constants.baseURL?.appending(component: "me") }
        
        var uri: URLConvertible? {
            switch self {
            case .get:
                return url
            }
        }
        
        var method: HTTPMethod {
            switch self {
            case .get:
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
            case .get:
                break
            }
            return request
        }
    }
}
