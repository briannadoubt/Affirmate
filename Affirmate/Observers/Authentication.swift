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
    
    let http = HTTPActor()
    let meActor = MeActor()
    
    @MainActor private func setState(to newState: Authentication.State) {
        withAnimation {
            state = newState
        }
    }
    
    func setCurrentAuthenticationState() async {
        await setState(to: http.interceptor.jwtToken == nil ? .loggedOut : .loggedIn)
    }
    
    @MainActor func setCurrentUser(to user: User?) {
        withAnimation {
            self.currentUser = user
        }
    }
    
    func getCurrentUser() async throws {
        let me = try await meActor.get()
        await setCurrentUser(to: me)
    }
    
    func signUp(userCreate: User.Create) async throws {
        let request = AF.request(Request.new(user: userCreate))
        let dataTask = request.serializingDecodable(User.self)
        let response = await dataTask.response
        if let error = response.error {
            throw error
        }
        let userResponse = try await dataTask.result.get()
        await setCurrentUser(to: userResponse)
    }
    
    func login(username: String, password: String) async throws {
        let loginResponse = try await http.requestDecodable(Request.login(username: username, password: password), to: User.LoginResponse.self)
        try HTTPActor.Interceptor.set(loginResponse.jwt)
        await setCurrentUser(to: loginResponse.user)
        await setState(to: .loggedIn)
    }
    
    static func refreshToken(_ oldToken: String) async throws -> JWTToken.Response {
        let newToken = try await HTTPActor().requestDecodable(Request.refresh(token: oldToken), to: JWTToken.Response.self)
        return newToken
    }
    
    func signOut() async throws {
        try HTTPActor.Interceptor.removeTokens()
        await setCurrentUser(to: nil)
        await setCurrentAuthenticationState()
    }
    
    enum Request: URLRequestConvertible {
        case new(user: User.Create)
        case login(username: String, password: String)
        case refresh(token: String)

        var url: URL? { Constants.baseURL?.appending(component: "auth") }
        
        var uri: URLConvertible? {
            switch self {
            case .new:
                return url?.appending(path: "new")
            case .login:
                return url?.appending(path: "login")
            case .refresh:
                return url?.appending(path: "validate")
            }
        }

        var method: HTTPMethod {
            switch self {
            case .new, .refresh:
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
            case .refresh(let token):
                headers.add(.authorization(token))
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
            case .login, .refresh:
                break
            }
            return request
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
    case failedToRemoveTokenFromKeychain
}
