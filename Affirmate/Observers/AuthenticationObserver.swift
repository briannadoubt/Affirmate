//
//  AuthenticationObserver.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI

final class AuthenticationObserver: ObservableObject {
    
    @Published var state: AuthenticationObserver.State = .initial
    @Published var currentUser: AffirmateUser?
    
    let authenticationActor = AuthenticationActor()
    let meActor = AffirmateUserActor()
    
    func setCurrentAuthenticationState() async {
        await setState(to: authenticationActor.http.interceptor.sessionToken == nil ? .loggedOut : .loggedIn)
    }
    
    @MainActor private func setState(to newState: AuthenticationObserver.State) {
        withAnimation {
            state = newState
        }
    }
    
    @MainActor func setCurrentUser(to user: AffirmateUser?) {
        withAnimation {
            self.currentUser = user
        }
    }
    
    func getCurrentUser() async throws {
        let me = try await meActor.me()
        await setCurrentUser(to: me)
    }
    
    func signUp(user create: AffirmateUser.Create) async throws {
        await setState(to: .loading(message: "Signing up..."))
        try await authenticationActor.signUp(user: create)
        try await login(username: create.username, password: create.password)
    }
    
    func login(username: String, password: String) async throws {
        do {
            await setState(to: .loading(message: "Logging in..."))
            let loginResponse = try await authenticationActor.login(username: username, password: password)
            try authenticationActor.interceptor.set(loginResponse.sessionToken)
            await setCurrentUser(to: loginResponse.user)
            await setState(to: .loggedIn)
        } catch {
            await setState(to: .loggedOut)
            throw error
        }
    }
    
    func signOut() async throws {
        let previousState = state
        do {
            await setState(to: .loading(message: "Logging out..."))
            try await authenticationActor.logout()
            await setCurrentUser(to: nil)
            await setState(to: .loggedOut)
        } catch {
            await setState(to: previousState)
            throw error
        }
    }
    
    func refresh(deviceToken token: Data?) async throws {
        try await authenticationActor.refresh(deviceToken: token)
    }
    
    enum State {
        case initial
        case loading(message: String)
        case loggedOut
        case loggedIn
        
        var message: String? {
            switch self {
            case .initial:
                return "Preparing..."
            case .loading(let message):
                return "Loading: " + message
            default:
                return nil
            }
        }
    }
}

extension AuthenticationObserver {
    
    enum ViewState: String, CaseIterable, Identifiable {
        case login
        case signUp
        var id: String { rawValue }
        var labelText: String {
            switch self {
            case .signUp:
                return "Sign Up"
            case .login:
                return "Login"
            }
        }
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
    
    var errorDescription: String? {
        switch self {
        case .failedToBuildURL:
            return "Failed to build URL."
        case .failedToEncodeCredentials:
            return "Failed to encode credentials."
        case .serverError(let serverError):
            return "Server Error: \(serverError.error)."
        case .failedToSaveTokenToKeychain:
            return "Failed to save token to Keychain."
        case .failedToGetTokenFromKeychain:
            return "Failed to get token from Keychain."
        case .failedToDecodeUser:
            return "Failed to decode user."
        case .failedToRemoveTokenFromKeychain:
            return "Failed to remove token from the Keychain."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .failedToBuildURL:
            return ""
        case .failedToEncodeCredentials:
            return ""
        case .serverError(let serverError):
            return serverError.reason
        case .failedToSaveTokenToKeychain:
            return ""
        case .failedToGetTokenFromKeychain:
            return ""
        case .failedToDecodeUser:
            return ""
        case .failedToRemoveTokenFromKeychain:
            return ""
        }
    }
}