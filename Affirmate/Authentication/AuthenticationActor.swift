//
//  AuthenticationActor.swift
//  Affirmate
//
//  Created by Bri on 9/7/22.
//

import Foundation
import Alamofire

protocol AuthenticationActable: Repository, Actor {
    func signUp(user create: AffirmateUser.Create) async throws
    func login(username: String, password: String) async throws -> AffirmateUser.LoginResponse
    func refresh(sessionToken: SessionToken) async throws -> SessionToken
    func update(deviceToken token: Data?) async throws
    func logout() async throws
}

actor AuthenticationActor: AuthenticationActable {
    
    func signUp(user create: AffirmateUser.Create) async throws {
        try await http.request(unauthorized: Request.new(user: create))
    }
    
    func login(username: String, password: String) async throws -> AffirmateUser.LoginResponse {
        try await http.requestDecodable(Request.login(username: username, password: password), to: AffirmateUser.LoginResponse.self)
    }
    
    func refresh(sessionToken: SessionToken) async throws -> SessionToken {
        try await http.requestDecodable(Request.refresh(sessionToken: sessionToken), to: SessionToken.self)
    }
    
    func update(deviceToken token: Data?) async throws {
        try await http.request(Request.update(deviceToken: token))
    }
    
    func logout() async throws {
        try await http.request(Request.logout)
    }
}

extension AuthenticationActor {
    
    enum Request: URLRequestConvertible {
    
        case new(user: AffirmateUser.Create)
        case login(username: String, password: String)
        case refresh(sessionToken: SessionToken)
        case update(deviceToken: Data?)
        case logout

        #if os(macOS)
        var url: URL { Constants.baseURL.appendingPathComponent("auth") }
        #else
        var url: URL { Constants.baseURL.appending(component: "auth") }
        #endif
        
        #if os(macOS)
        var uri: URLConvertible? {
            switch self {
            case .new:
                return url.appendingPathComponent("new")
            case .login:
                return url.appendingPathComponent("login")
            case .refresh:
                return url.appendingPathComponent("refresh")
            case .update:
                return url.appendingPathComponent("deviceToken")
            case .logout:
                return url.appendingPathComponent("logout")
            }
        }
        #else
        var uri: URLConvertible? {
            switch self {
            case .new:
                return url.appending(path: "new")
            case .login:
                return url.appending(path: "login")
            case .refresh:
                return url.appending(path: "refresh")
            case .update:
                return url.appending(path: "deviceToken")
            case .logout:
                return url.appending(path: "logout")
            }
        }
        #endif

        var method: HTTPMethod {
            switch self {
            case .new, .logout, .refresh:
                return .post
            case .login:
                return .get
            case .update:
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
            case .new, .update, .logout, .refresh:
                break
            case let .login(username, password):
                headers.add(.authorization(username: username, password: password))
            }
            return headers
        }

        func asURLRequest() throws -> URLRequest {
            guard let requestURL = uri else {
                throw ChatError.failedToBuildURL
            }
            var request = try URLRequest(url: requestURL, method: method, headers: headers)
            let encoder = JSONEncoder()
            switch self {
            case .new(let user):
                request.httpBody = try encoder.encode(user)
            case .update(let deviceToken):
                request.httpBody = try encoder.encode(APNSDeviceToken(token: deviceToken))
            case .refresh(let sessionToken):
                request.httpBody = try encoder.encode(sessionToken)
            case .login, .logout:
                break
            }
            return request
        }
        
        struct APNSDeviceToken: Codable {
            var token: Data?
        }
    }
}
