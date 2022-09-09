//
//  AuthenticationActor.swift
//  Affirmate
//
//  Created by Bri on 9/7/22.
//

import Foundation
import Alamofire

actor AuthenticationActor: Repository {
    
    func signUp(user create: AffirmateUser.Create) async throws {
        try await http.request(unauthorized: Request.new(user: create))
    }
    
    func login(username: String, password: String) async throws -> AffirmateUser.LoginResponse {
        try await http.requestDecodable(Request.login(username: username, password: password), to: AffirmateUser.LoginResponse.self)
    }
    
    func refresh(deviceToken token: Data?) async throws {
        try await http.request(Request.refresh(deviceToken: token))
    }
    
    func logout() async throws {
        try await http.request(Request.logout)
        try? interceptor.removeTokens()
    }
}

extension AuthenticationActor {
    
    enum Request: URLRequestConvertible {
    
        case new(user: AffirmateUser.Create)
        case login(username: String, password: String)
//        case refresh(token: String)
        case refresh(deviceToken: Data?)
        case logout

        var url: URL { Constants.baseURL.appending(component: "auth") }
        
        var uri: URLConvertible? {
            switch self {
            case .new:
                return url.appending(path: "new")
            case .login:
                return url.appending(path: "login")
//            case .refresh:
//                return url.appending(path: "validate")
            case .refresh:
                return url.appending(path: "deviceToken")
            case .logout:
                return url.appending(path: "logout")
            }
        }

        var method: HTTPMethod {
            switch self {
            case .new, .logout://, .refresh:
                return .post
            case .login:
                return .get
            case .refresh:
                return .put
            }
        }
        
        var headers: HTTPHeaders {
            var headers = HTTPHeaders()
            headers.add(.defaultAcceptLanguage)
            headers.add(.defaultUserAgent)
            headers.add(.defaultAcceptEncoding)
            headers.add(.contentType("application/json"))
            headers.add(.accept("application/json"))
            switch self {
            case .new, .refresh, .logout:
                break
            case let .login(username, password):
                headers.add(.authorization(username: username, password: password))
//            case .refresh(let token):
//                headers.add(.authorization(token))
            }
            return headers
        }

        func asURLRequest() throws -> URLRequest {
            guard let requestURL = uri else {
                throw ChatError.failedToBuildURL
            }
            var request = try URLRequest(url: requestURL, method: method, headers: headers)
            switch self {
            case .new(let user):
                request.httpBody = try JSONEncoder().encode(user)
            case .refresh(let deviceToken):
                request.httpBody = try JSONEncoder().encode(APNSDeviceToken(token: deviceToken))
            case .login, .logout://, .refresh:
                break
            }
            return request
        }
        
        struct APNSDeviceToken: Codable {
            var token: Data?
        }
    }
}
