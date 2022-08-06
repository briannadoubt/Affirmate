//
//  AppState.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI
import SwiftKeychainWrapper

enum AuthenticationState: String {
    case initial
    case loading
    case loggedOut
    case loggedIn
}

enum AuthenticationError: LocalizedError {
    case failedToBuildURL
    case failedToEncodeCredentials
    case serverError(ServerError)
    case failedToSaveTokenToKeychain
    case failedToDecodeUser
}

final class AuthenticationObserver: ObservableObject {
    
    @Published var state: AuthenticationState = .initial
    @Published var currentUser: User?
    
    @MainActor private func setState(to newState: AuthenticationState) {
        withAnimation {
            state = newState
        }
    }
    
    func setCurrentAuthenticationState() async {
        await setState(to: getKeychainToken() == nil ? .loggedOut : .loggedIn)
    }
    
    @MainActor func setCurrentUser(to user: User) {
        withAnimation {
            self.currentUser = currentUser
        }
    }
    
    func getKeychainToken() -> String? {
        KeychainWrapper.standard.string(forKey: Constants.tokenKey)
    }
    
    func login(email: String, password: String) async throws {
        guard
            let loginString = "\(email):\(password)".data(using: .utf8)?.base64EncodedString(),
            let loginUrl = Constants.authURL?.appending(component: "login")
        else {
            throw AuthenticationError.failedToEncodeCredentials
        }
        var request = URLRequest(url: loginUrl)
        request.httpMethod = "POST"
        request.setValue("Basic \(loginString)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        if let serverError = try? decoder.decode(ServerError.self, from: data) {
            throw AuthenticationError.serverError(serverError)
        }
        let token = try decoder.decode(UserToken.self, from: data)
        if !KeychainWrapper.standard.set(token.value, forKey: Constants.tokenKey) {
            throw AuthenticationError.failedToSaveTokenToKeychain
        }
        await setState(to: .loggedIn)
    }
    
    func signUp(userCreate: User.Create) async throws {
        guard let signUpUrl = Constants.authURL?.appending(component: "new") else {
            throw AuthenticationError.failedToBuildURL
        }
        var request = URLRequest(url: signUpUrl)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(userCreate)
        
        await setState(to: .loading)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        if let serverError = try? decoder.decode(ServerError.self, from: data) {
            throw AuthenticationError.serverError(serverError)
        }
        guard let user = try? decoder.decode(User.self, from: data) else {
            print(try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:])
            await setState(to: .loggedOut)
            throw AuthenticationError.failedToDecodeUser
        }
        await setCurrentUser(to: user)
        try await login(email: userCreate.email, password: userCreate.password)
    }
}
