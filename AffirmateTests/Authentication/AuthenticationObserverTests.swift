//
//  AuthenticationObserverTests.swift
//  AffirmateTests
//
//  Created by Bri on 11/20/22.
//

import AffirmateShared
@testable import Affirmate
import XCTest
import KeychainAccess

final class AuthenticationObserverTests: XCTestCase {

    var observer: AuthenticationObserver!
    var meActor: MockUserActor!
    var authenticationActor: MockAuthenticationActor!
    var sessionKeychain: Keychain!
    var http: MockHTTPActor!
    
    static let userId = UUID()
    static let firstName = "Meow"
    static let lastName = "Face"
    static let username = "meowface"
    static let email = "meow@fake.com"
    static let password = "Test123$"
    static let confirmPassword = "Test123$"
    static let chatInvitations: [ChatInvitationResponse] = []
    
    var currentUser: UserResponse {
        UserResponse(id: Self.userId, firstName: Self.firstName, lastName: Self.lastName, username: Self.username, email: Self.email, chatInvitations: Self.chatInvitations)
    }
    
    var userCreate: UserCreate {
        UserCreate(firstName: Self.firstName, lastName: Self.lastName, username: Self.username, email: Self.email, password: Self.password, confirmPassword: Self.confirmPassword)
    }
    
    var loginResponse: UserLoginResponse {
        UserLoginResponse(sessionToken: sessionTokenResponse, user: currentUser)
    }
    
    var sessionTokenResponse: SessionTokenResponse {
        SessionTokenResponse(id: UUID(), value: "sldjngrsoergosudrgbnosergpsirj")
    }
    
    override func setUpWithError() throws {
        sessionKeychain = Keychain()
        do { try sessionKeychain.removeAll() } catch { }
        meActor = MockUserActor()
        http = MockHTTPActor(keychain: sessionKeychain)
        authenticationActor = MockAuthenticationActor(http: http)
        observer = AuthenticationObserver(authenticationActor: authenticationActor, meActor: meActor, sessionKeychain: sessionKeychain)
    }

    override func tearDownWithError() throws {
        do { try sessionKeychain.removeAll() } catch { }
        sessionKeychain = nil
        observer = nil
        authenticationActor = nil
        meActor = nil
    }
    
    func test_initialValues() {
        XCTAssertEqual(observer.state, .initial)
        XCTAssertEqual(observer.currentUser, nil)
    }
    
    func test_setCurrentAuthenticationState() async throws {
        try observer.store(sessionToken: sessionTokenResponse)
        XCTAssertEqual(sessionKeychain[string: Constants.KeyChain.Session.token], sessionTokenResponse.value)
        await observer.setCurrentAuthenticationState()
        XCTAssertEqual(observer.state, .loggedIn)
    }
    
    func test_setCurrentAuthenticationState_sessionTokenIsNil() async throws {
        XCTAssertNil(sessionKeychain[string: Constants.KeyChain.Session.token])
        await observer.setCurrentAuthenticationState()
        XCTAssertEqual(observer.state, .loggedOut)
    }
    
    @MainActor func test_setState() {
        XCTAssertEqual(observer.state, .initial)
        let state = AuthenticationObserver.State.loggedOut
        observer.setState(to: state)
        XCTAssertEqual(observer.state, state)
    }
    
    @MainActor func test_setCurrentUser() throws {
        observer.setCurrentUser(to: currentUser)
        XCTAssertEqual(observer.currentUser, currentUser)
    }
    
    @MainActor func test_setCurrentUser_nilValue() throws {
        try observer.store(sessionToken: sessionTokenResponse)
        XCTAssertEqual(sessionKeychain[string: Constants.KeyChain.Session.token], sessionTokenResponse.value)
        observer.setCurrentUser(to: nil)
        XCTAssertNil(observer.currentUser)
        XCTAssertNil(sessionKeychain[string: Constants.KeyChain.Session.token])
    }

    func test_getCurrentUser() async throws {
        MockUserActor.user = currentUser
        try await observer.getCurrentUser()
        let calledMe = await meActor.called_me
        XCTAssertEqual(calledMe, 1)
        XCTAssertEqual(observer.currentUser, currentUser)
    }
    
    func test_getCurrentUser_meActorFailed() async throws {
        MockUserActor.user = currentUser
        MockAuthenticationActor.loginResponse = loginResponse
        try await observer.login(username: Self.username, password: Self.password)
        XCTAssertEqual(observer.state, .loggedIn)
        XCTAssertEqual(observer.currentUser, currentUser)
        XCTAssertEqual(sessionKeychain[Constants.KeyChain.Session.token], sessionTokenResponse.value)
        
        await meActor.set(shouldFail: true)
        do {
            try await observer.getCurrentUser()
            XCTFail("Getting current user should fail in this test.")
        } catch {
            let error = try XCTUnwrap(error as? MockError)
            XCTAssertEqual(error, .youToldMeTo)
            let calledMe = await meActor.called_me
            XCTAssertEqual(calledMe, 1)
            XCTAssertEqual(observer.currentUser, nil)
            XCTAssertNil(sessionKeychain[Constants.KeyChain.Session.token])
        }
    }
    
    func test_signUp() async throws {
        MockUserActor.user = currentUser
        MockAuthenticationActor.loginResponse = loginResponse
        try await observer.signUp(user: userCreate)
        let called_signUp = await authenticationActor.called_signUp
        let called_login = await authenticationActor.called_login
        XCTAssertEqual(called_signUp, 1)
        XCTAssertEqual(called_login, 1)
        XCTAssertEqual(observer.state, .loggedIn)
        XCTAssertEqual(sessionKeychain[Constants.KeyChain.Session.token], sessionTokenResponse.value)
    }
    
    func test_signUp_authenticationActorFailed() async throws {
        await authenticationActor.set(shouldFail: true)
        do {
            try await observer.signUp(user: userCreate)
            XCTFail("Sign up should fail when authentication actor fails.")
        } catch {
            let error = try XCTUnwrap(error as? MockError)
            XCTAssertEqual(error, .youToldMeTo)
            let called_signUp = await authenticationActor.called_signUp
            let called_login = await authenticationActor.called_login
            XCTAssertEqual(called_signUp, 1)
            XCTAssertEqual(called_login, 0)
            XCTAssertEqual(observer.state, .loggedOut)
            XCTAssertNil(sessionKeychain[Constants.KeyChain.Session.token])
        }
    }
    
    func test_login() async throws {
        MockUserActor.user = currentUser
        MockAuthenticationActor.loginResponse = loginResponse
        
        try await observer.login(username: Self.username, password: Self.password)
        
        let called_login = await authenticationActor.called_login
        XCTAssertEqual(called_login, 1)
        XCTAssertEqual(observer.state, .loggedIn)
        XCTAssertEqual(observer.currentUser, currentUser)
        XCTAssertEqual(sessionKeychain[Constants.KeyChain.Session.token], sessionTokenResponse.value)
    }
    
    func test_login_authenticationActorFailed() async throws {
        MockUserActor.user = currentUser
        MockAuthenticationActor.loginResponse = loginResponse
        
        await authenticationActor.set(shouldFail: true)
        do {
            try await observer.login(username: Self.username, password: Self.password)
            XCTFail("Login should throw an error in this test.")
        } catch {
            let error = try XCTUnwrap(error as? MockError)
            XCTAssertEqual(error, .youToldMeTo)
            let called_login = await authenticationActor.called_login
            XCTAssertEqual(called_login, 1)
            XCTAssertEqual(observer.state, .loggedOut)
            XCTAssertNil(sessionKeychain[Constants.KeyChain.Session.token])
            XCTAssertNil(observer.currentUser)
        }
    }
    
    func test_signOut() async throws {
        MockUserActor.user = currentUser
        MockAuthenticationActor.loginResponse = loginResponse
        try await observer.login(username: Self.username, password: Self.password)
        XCTAssertEqual(observer.state, .loggedIn)
        XCTAssertEqual(sessionKeychain[string: Constants.KeyChain.Session.token], sessionTokenResponse.value)
        
        try await observer.signOut()
        
        let called_signOut = await authenticationActor.called_logout
        XCTAssertEqual(called_signOut, 1)
        XCTAssertEqual(observer.state, .loggedOut)
        XCTAssertNil(observer.currentUser)
        XCTAssertNil(sessionKeychain[Constants.KeyChain.Session.token])
    }
    
    func test_signOut_authenticationActorFailed() async throws {
        await authenticationActor.set(shouldFail: true)
        do {
            try await observer.signOut()
            XCTFail("Sign out should fail when authentication actor fails.")
        } catch {
            let error = try XCTUnwrap(error as? MockError)
            XCTAssertEqual(error, .youToldMeTo)
            let called_signOut = await authenticationActor.called_logout
            XCTAssertEqual(called_signOut, 1)
            XCTAssertEqual(observer.state, .loggedOut)
            XCTAssertNil(sessionKeychain[Constants.KeyChain.Session.token])
        }
    }
    
    func test_signOut_serverHasInvalidKey() async throws {
        MockUserActor.user = currentUser
        MockAuthenticationActor.loginResponse = loginResponse
        try await observer.login(username: Self.username, password: Self.password)
        XCTAssertEqual(observer.state, .loggedIn)
        
        try await observer.signOut(serverHasValidKey: false)
        
        let called_signOut = await authenticationActor.called_logout
        XCTAssertEqual(called_signOut, 0)
        XCTAssertEqual(observer.state, .loggedOut)
        XCTAssertNil(observer.currentUser)
        XCTAssertNil(sessionKeychain[Constants.KeyChain.Session.token])
    }
    
    func test_refresh() async throws {
        MockAuthenticationActor.sessionToken = sessionTokenResponse
        try await observer.refesh(sessionToken: sessionTokenResponse)
        let called_refresh = await authenticationActor.called_refresh
        XCTAssertEqual(called_refresh, 1)
        XCTAssertEqual(sessionKeychain[Constants.KeyChain.Session.token], sessionTokenResponse.value)
    }
    
    func test_refresh_authenticationActorFailed() async throws {
        MockAuthenticationActor.sessionToken = sessionTokenResponse
        await authenticationActor.set(shouldFail: true)
        do {
            try await observer.refesh(sessionToken: sessionTokenResponse)
            XCTFail("Observer should throw")
        } catch {
            let error = try XCTUnwrap(error as? MockError)
            XCTAssertEqual(error, .youToldMeTo)
            let called_refresh = await authenticationActor.called_refresh
            XCTAssertEqual(called_refresh, 1)
            XCTAssertNil(sessionKeychain[Constants.KeyChain.Session.token])
        }
    }
    
    func test_store() async throws {
        XCTAssertNil(sessionKeychain[Constants.KeyChain.Session.token])
        try observer.store(sessionToken: sessionTokenResponse)
        XCTAssertEqual(sessionKeychain[Constants.KeyChain.Session.token], sessionTokenResponse.value)
    }
    
    func test_store_nilValue() async throws {
        XCTAssertNil(sessionKeychain[Constants.KeyChain.Session.token])
        try observer.store(sessionToken: sessionTokenResponse)
        XCTAssertEqual(sessionKeychain[Constants.KeyChain.Session.token], sessionTokenResponse.value)
        try observer.store(sessionToken: nil)
        XCTAssertNil(sessionKeychain[Constants.KeyChain.Session.token])
    }
}
