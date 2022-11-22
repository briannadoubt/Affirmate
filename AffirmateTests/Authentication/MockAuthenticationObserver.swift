//
//  MockAuthenticationObserver.swift
//  AffirmateTests
//
//  Created by Bri on 10/21/22.
//

@testable import Affirmate
import AffirmateShared
import Foundation

class MockAuthenticationObserver: AuthenticationObservable {
    static var shared = MockAuthenticationObserver()
    
    @Published var state: AuthenticationObserver.State = .initial
    @Published var currentUser: UserResponse? = nil
    
    let authenticationActor = AuthenticationActor()
    let meActor = UserActor()
    
    var called_setCurrentAuthenticationState = 0
    var called_setState = 0
    var called_setCurrentUser = 0
    var called_getCurrentUser = 0
    var called_signUp = 0
    var called_login = 0
    var called_signOut = 0
    var called_update = 0
    var called_refesh = 0
    var called_store = 0
    
    func setCurrentAuthenticationState() async {
        called_setCurrentAuthenticationState += 1
    }
    
    func setState(to newState: AuthenticationObserver.State) {
        called_setState += 1
    }
    
    func setCurrentUser(to user: UserResponse?) {
        called_setCurrentUser += 1
    }
    
    func getCurrentUser() async throws {
        called_getCurrentUser += 1
    }
    
    func signUp(user create: UserCreate) async throws {
        called_signUp += 1
    }
    
    func login(username: String, password: String) async throws {
        called_login += 1
    }
    
    func signOut(serverHasValidKey: Bool) async throws {
        called_signOut += 1
    }
    
    func update(deviceToken token: Data?) async throws {
        called_update += 1
    }
    
    func refesh(sessionToken: SessionTokenResponse) async throws {
        called_refesh += 1
    }
    
    func store(sessionToken: SessionTokenResponse?) throws {
        called_store += 1
    }
}
