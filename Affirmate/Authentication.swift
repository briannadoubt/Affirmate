//
//  Authentication.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI
import SwiftKeychainWrapper
import Alamofire

final class Authentication: ObservableObject {
    
    @Published var state: Authentication.State = .initial
    
    @Published var currentUser: User?
    
    @MainActor private func setState(to newState: Authentication.State) {
        withAnimation {
            state = newState
        }
    }
    
    func setCurrentAuthenticationState() async {
        await setState(to: getKeychainToken() == nil ? .loggedOut : .loggedIn)
    }
    
    @MainActor func setCurrentUser(to user: User?) {
        withAnimation {
            self.currentUser = currentUser
        }
    }
    
    func getKeychainToken() -> String? {
        KeychainWrapper.standard.string(forKey: Constants.tokenKey)
    }
    
    func login(username: String, password: String) async throws {
        let request = AF.request(Request.login(username: username, password: password), interceptor: Request.TokenInterceptor())
        let dataTask = request.serializingDecodable(Token.Response.self)
        let response = await dataTask.response
        if let error = response.error {
            throw error
        }
        let tokenResponse = try await dataTask.result.get()
        if !KeychainWrapper.standard.set(
            tokenResponse.token,
            forKey: Constants.tokenKey,
            withAccessibility: .afterFirstUnlock,
            isSynchronizable: true
        ) {
            throw AuthenticationError.failedToSaveTokenToKeychain
        }
        await setState(to: .loggedIn)
    }
    
    func signUp(userCreate: User.Create) async throws {
        let request = AF.request(Request.new(user: userCreate), interceptor: Request.TokenInterceptor())
        let dataTask = request.serializingDecodable(User.self)
        let response = await dataTask.response
        if let error = response.error {
            throw error
        }
        let userResponse = try await dataTask.result.get()
        await setCurrentUser(to: userResponse)
    }
    
    func signOut() async throws {
        if !KeychainWrapper.standard.removeObject(forKey: Constants.tokenKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true) {
            throw AuthenticationError.failedToGetTokenFromKeychain
        }
        await setCurrentUser(to: nil)
        await setCurrentAuthenticationState()
    }
    
    enum Request: URLRequestConvertible {
        case new(user: User.Create)
        case login(username: String, password: String)

        var baseURL: URL { Constants.authURL! }
        
        var url: URLConvertible {
            switch self {
            case .new:
                return baseURL.appending(path: "new")
            case .login:
                return baseURL.appending(path: "login")
            }
        }

        var method: HTTPMethod {
            switch self {
            case .new:
                return .post
            case .login:
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
            switch self {
            case .new:
                break
            case let .login(username, password):
                headers.add(.authorization(username: username, password: password))
            }
            return headers
        }

        func asURLRequest() throws -> URLRequest {
            var request = try URLRequest(url: url, method: method, headers: headers)
            switch self {
            case .new(let user):
                request.httpBody = try JSONEncoder().encode(user)
            case .login:
                break
            }
            return request
        }
        
        struct TokenInterceptor: RequestInterceptor {
            var token: Token.Response?
            func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
                var request = urlRequest
                if let tokenResponse = token {
                    request.headers.add(.authorization(bearerToken: tokenResponse.token))
                }
                return completion(.success(request))
            }
        }
    }
    
    enum State: String {
        case initial
        case loading
        case loggedOut
        case loggedIn
    }
}

enum AuthenticationError: LocalizedError {
    case failedToBuildURL
    case failedToEncodeCredentials
    case serverError(ServerError)
    case failedToSaveTokenToKeychain
    case failedToGetTokenFromKeychain
    case failedToDecodeUser
}
