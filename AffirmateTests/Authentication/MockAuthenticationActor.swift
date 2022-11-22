//
//  MockAuthenticationActor.swift
//  AffirmateTests
//
//  Created by Bri on 11/20/22.
//

@testable import Affirmate
import Foundation

enum MockError: LocalizedError {
    case noValueSet
}

actor MockAuthenticationActor: AuthenticationActable {
    static var loginResponse: User.LoginResponse?
    static var sessionToken: SessionToken?
    
    var called_signUp = 0
    var called_login = 0
    var called_refresh = 0
    var called_update = 0
    var called_logout = 0
    
    func signUp(user create: User.Create) async throws {
        called_signUp += 1
    }
    
    func login(username: String, password: String) async throws -> Affirmate.User.LoginResponse {
        called_login += 1
        guard let loginResponse = Self.loginResponse else {
            throw MockError.noValueSet
        }
        return loginResponse
    }
    
    func refresh(sessionToken: Affirmate.SessionToken) async throws -> Affirmate.SessionToken {
        called_refresh += 1
        guard let sessionToken = Self.sessionToken else {
            throw MockError.noValueSet
        }
        return sessionToken
    }
    
    func update(deviceToken token: Data?) async throws {
        called_update += 1
    }
    
    func logout() async throws {
        called_logout += 1
    }
}
