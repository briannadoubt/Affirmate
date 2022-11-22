//
//  MockAuthenticationActor.swift
//  AffirmateTests
//
//  Created by Bri on 11/20/22.
//

#if os(watchOS)
@testable import AffirmateWatch
#else
@testable import Affirmate
#endif
import AffirmateShared
import Foundation

enum MockError: LocalizedError {
    case noValueSet
    case youToldMeTo
}

actor MockAuthenticationActor: AuthenticationActable {
    var http: HTTPActable
    
    init(http: HTTPActable) {
        self.http = http
    }
    
    static var loginResponse: UserLoginResponse?
    static var sessionToken: SessionTokenResponse?
    
    var called_signUp = 0
    var called_login = 0
    var called_refresh = 0
    var called_update = 0
    var called_logout = 0
    
    var shouldFail = false
    
    func set(shouldFail: Bool) {
        self.shouldFail = shouldFail
    }
    
    func signUp(user create: UserCreate) async throws {
        called_signUp += 1
        if shouldFail {
            throw MockError.youToldMeTo
        }
    }
    
    func login(username: String, password: String) async throws -> UserLoginResponse {
        called_login += 1
        guard let loginResponse = Self.loginResponse else {
            throw MockError.noValueSet
        }
        if shouldFail {
            throw MockError.youToldMeTo
        }
        return loginResponse
    }
    
    func refresh(sessionToken: SessionTokenResponse) async throws -> SessionTokenResponse {
        called_refresh += 1
        guard let sessionToken = Self.sessionToken else {
            throw MockError.noValueSet
        }
        if shouldFail {
            throw MockError.youToldMeTo
        }
        return sessionToken
    }
    
    func update(deviceToken token: Data?) async throws {
        called_update += 1
        if shouldFail {
            throw MockError.youToldMeTo
        }
    }
    
    func logout() async throws {
        called_logout += 1
        if shouldFail {
            throw MockError.youToldMeTo
        }
    }
}
