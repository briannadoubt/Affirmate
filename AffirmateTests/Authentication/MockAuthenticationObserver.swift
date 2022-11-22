//
//  MockAuthenticationObserver.swift
//  AffirmateTests
//
//  Created by Bri on 10/21/22.
//

@testable import Affirmate
import Foundation

class MockAuthenticationObserver: AuthenticationObservable {
    static var shared = MockAuthenticationObserver()
    
    @Published var state: AuthenticationObserver.State = .initial
    @Published var currentUser: User? = nil
    
    let authenticationActor = AuthenticationActor()
    let meActor = UserActor()
    
    var calls_setCurrentAuthenticationState = 0
    var calls_setState = 0
    var calls_setCurrentUser = 0
    var calls_getCurrentUser = 0
    var calls_signUp = 0
    var calls_login = 0
    var calls_signOut = 0
    var calls_update = 0
    var calls_refesh = 0
    var calls_store = 0
    
    func setCurrentAuthenticationState() async {
        calls_setCurrentAuthenticationState += 1
    }
    
    func setState(to newState: AuthenticationObserver.State) {
        calls_setState += 1
    }
    
    func setCurrentUser(to user: User?) {
        calls_setCurrentUser += 1
    }
    
    func getCurrentUser() async throws {
        calls_getCurrentUser += 1
    }
    
    func signUp(user create: User.Create) async throws {
        calls_signUp += 1
    }
    
    func login(username: String, password: String) async throws {
        calls_login += 1
    }
    
    func signOut(serverHasValidKey: Bool) async throws {
        calls_signOut += 1
    }
    
    func update(deviceToken token: Data?) async throws {
        calls_update += 1
    }
    
    func refesh(sessionToken: SessionToken) async throws {
        calls_refesh += 1
    }
    
    func store(sessionToken: SessionToken?) throws {
        calls_store += 1
    }
}
