//
//  AuthenticationObserver.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import AffirmateShared
import SwiftUI

protocol AuthenticationObservable: ObservableObject {
    associatedtype _AuthenticationObservable
    static var shared: _AuthenticationObservable { get set }
    var state: AuthenticationObserver.State { get set }
    var currentUser: UserResponse? { get set }
    associatedtype _AuthenticationActable = AuthenticationActable
    var authenticationActor: _AuthenticationActable { get }
    associatedtype _UserActable = UserActable
    var meActor: _UserActable { get }
    func setCurrentAuthenticationState() async
    func setState(to newState: AuthenticationObserver.State)
    func setCurrentUser(to user: UserResponse?)
    func getCurrentUser() async throws
    func signUp(user create: UserCreate) async throws
    func login(username: String, password: String) async throws
    func signOut(serverHasValidKey: Bool) async throws
    func update(deviceToken token: Data?) async throws
    func refesh(sessionToken: SessionTokenResponse) async throws
    func store(sessionToken: SessionTokenResponse?) throws
}

final class AuthenticationObserver: AuthenticationObservable {
    
    static var shared = AuthenticationObserver()
    
    @Published var state: AuthenticationObserver.State = .initial
    @Published var currentUser: UserResponse?
    
    let authenticationActor: AuthenticationActable
    let meActor: UserActor
    
    init(
        authenticationActor: AuthenticationActable = AuthenticationActor(),
        meActor: UserActor = UserActor()
    ) {
        self.authenticationActor = authenticationActor
        self.meActor = meActor
    }
    
    func setCurrentAuthenticationState() async {
        await setState(to: authenticationActor.http.interceptor.sessionToken == nil ? .loggedOut : .loggedIn)
    }
    
    @MainActor func setState(to newState: AuthenticationObserver.State) {
        withAnimation {
            state = newState
        }
    }
    
    @MainActor func setCurrentUser(to user: UserResponse?) {
        withAnimation {
            self.currentUser = user
            if user == nil {
                do {
                    try AffirmateKeychain.session.remove(Constants.KeyChain.Session.token)
                } catch {
                    print("Failed to remove tokens")
                }
            }
        }
    }
    
    func getCurrentUser() async throws {
        do {
            let me = try await meActor.me()
            await setCurrentUser(to: me)
        } catch {
            await setCurrentUser(to: nil)
        }
    }
    
    func signUp(user create: UserCreate) async throws {
        await setState(to: .loading(message: "Signing up..."))
        do {
            try await authenticationActor.signUp(user: create)
        } catch {
            await setState(to: .loggedOut)
            throw error
        }
        try await login(username: create.username, password: create.password)
    }
    
    func login(username: String, password: String) async throws {
        do {
            await setState(to: .loading(message: "Logging in..."))
            let loginResponse = try await authenticationActor.login(username: username, password: password)
            try store(sessionToken: loginResponse.sessionToken)
            await setCurrentUser(to: loginResponse.user)
            await setState(to: .loggedIn)
        } catch {
            await setState(to: .loggedOut)
            throw error
        }
    }
    
    func signOut(serverHasValidKey: Bool = true) async throws {
        let previousState = state
        do {
            await setState(to: .loading(message: "Logging out..."))
            try AffirmateKeychain.session.remove(Constants.KeyChain.Session.token)
            await setCurrentUser(to: nil)
            await setState(to: .loggedOut)
        } catch {
            await setState(to: previousState)
            throw error
        }
        if serverHasValidKey {
            do {
                try await authenticationActor.logout()
            } catch {
                print("Log out request failed:", error)
            }
        }
    }
    
    func update(deviceToken token: Data?) async throws {
        try await authenticationActor.update(deviceToken: token)
    }
    
    func refesh(sessionToken: SessionTokenResponse) async throws {
        let newSessionToken = try await authenticationActor.refresh(sessionToken: sessionToken)
        try store(sessionToken: nil)
        try store(sessionToken: newSessionToken)
    }
    
    func store(sessionToken: SessionTokenResponse?) throws {
        if let sessionToken {
            try AffirmateKeychain.session.set(sessionToken.value, key: Constants.KeyChain.Session.token)
        } else {
            try AffirmateKeychain.session.remove(Constants.KeyChain.Session.token)
        }
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
